# ---------------------------------------------------------------------------
# install-openclaw-service.ps1
# Registers `openclaw gateway` as an auto-starting Windows Service using NSSM
# (the Non-Sucking Service Manager). NSSM is the standard wrapper for turning
# arbitrary console applications into well-behaved Windows services - it
# handles the SCM protocol that openclaw itself does not implement.
#
# Prerequisites:
#   * install-openclaw.ps1 must have run first (installs Node + openclaw + choco)
#   * Run as Administrator
#   * Supply -RunAsUser/-RunAsPassword if the gateway must read a specific
#     user's %USERPROFILE%\.openclaw config (recommended).
# ---------------------------------------------------------------------------

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$ServiceName    = 'OpenClawGateway',
    [string]$ServiceDisplay = 'OpenClaw Gateway',
    [string]$ServiceDesc    = 'OpenClaw AI agent gateway. Hosts the local HTTP back-end on port 18789.',
    [int]   $GatewayPort    = 18789,

    # Account whose %USERPROFILE%\.openclaw config the gateway should use.
    # Leave blank to run as LocalSystem.
    [string]$RunAsUser      = 'clawadmin',
    [string]$RunAsPassword,

    [string]$LogDir         = 'C:\ProgramData\OpenClaw\logs'
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Step 1 - Locate openclaw.cmd (installed by install-openclaw.ps1)
# ---------------------------------------------------------------------------
Write-Host ">>> Locating openclaw executable..."
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path','User')

$candidates = @(
    'D:\openclaw\node_modules\.bin\openclaw.cmd',
    'C:\Program Files\nodejs\openclaw.cmd'
)
$OpenclawCmd = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $OpenclawCmd) {
    $found = Get-Command openclaw.cmd -ErrorAction SilentlyContinue
    if ($found) { $OpenclawCmd = $found.Source }
}
if (-not $OpenclawCmd) {
    throw "Could not find openclaw.cmd. Run install-openclaw.ps1 first."
}
Write-Host "Found: $OpenclawCmd"

# ---------------------------------------------------------------------------
# Step 2 - Ensure NSSM is installed (via Chocolatey)
# ---------------------------------------------------------------------------
Write-Host ">>> Ensuring NSSM is installed..."
$nssm = (Get-Command nssm.exe -ErrorAction SilentlyContinue).Source
if (-not $nssm) {
    $choco = 'C:\ProgramData\chocolatey\bin\choco.exe'
    if (-not (Test-Path $choco)) {
        throw "Chocolatey not found at $choco. Run install-openclaw.ps1 first."
    }
    & $choco install nssm -y
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path','User')
    $nssm = (Get-Command nssm.exe -ErrorAction SilentlyContinue).Source
    if (-not $nssm) { $nssm = 'C:\ProgramData\chocolatey\bin\nssm.exe' }
}
Write-Host "NSSM: $nssm"

# ---------------------------------------------------------------------------
# Step 3 - Remove any existing registration of this service
# ---------------------------------------------------------------------------
$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host ">>> Removing existing '$ServiceName' service..."
    if ($existing.Status -eq 'Running') {
        & $nssm stop   $ServiceName confirm | Out-Null
    }
    & $nssm remove $ServiceName confirm | Out-Null
    Start-Sleep -Seconds 2
}

# ---------------------------------------------------------------------------
# Step 4 - Prepare log directory
# ---------------------------------------------------------------------------
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# ---------------------------------------------------------------------------
# Step 5 - Install the service via NSSM
# ---------------------------------------------------------------------------
Write-Host ">>> Installing '$ServiceName' service via NSSM..."

# Host openclaw.cmd through cmd.exe so console hand-off works correctly.
& $nssm install $ServiceName 'cmd.exe' '/c' "`"$OpenclawCmd`" gateway"

& $nssm set $ServiceName DisplayName            $ServiceDisplay
& $nssm set $ServiceName Description             $ServiceDesc
& $nssm set $ServiceName Start                   SERVICE_DELAYED_AUTO_START
& $nssm set $ServiceName AppDirectory            (Split-Path $OpenclawCmd -Parent)
& $nssm set $ServiceName AppStdout               (Join-Path $LogDir 'gateway.out.log')
& $nssm set $ServiceName AppStderr               (Join-Path $LogDir 'gateway.err.log')
& $nssm set $ServiceName AppRotateFiles          1
& $nssm set $ServiceName AppRotateOnline         1
& $nssm set $ServiceName AppRotateBytes          10485760   # rotate at 10 MB
& $nssm set $ServiceName AppStopMethodSkip       0           # graceful CTRL+C -> WM_CLOSE -> kill
& $nssm set $ServiceName AppStopMethodConsole    15000
& $nssm set $ServiceName AppThrottle             10000
& $nssm set $ServiceName AppExit Default         Restart    # auto-restart on crash
& $nssm set $ServiceName AppRestartDelay         5000
& $nssm set $ServiceName DependOnService         Tcpip

# Run as a real user so %USERPROFILE%\.openclaw resolves to the right config.
if ($RunAsUser) {
    if (-not $RunAsPassword) {
        $sec = Read-Host "Enter password for $RunAsUser" -AsSecureString
        $RunAsPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    }
    Write-Host "Configuring service to run as $RunAsUser..."
    & $nssm set $ServiceName ObjectName ".\$RunAsUser" $RunAsPassword
} else {
    Write-Host "Service will run as LocalSystem."
}

# ---------------------------------------------------------------------------
# Step 6 - Start the service
# ---------------------------------------------------------------------------
Write-Host ">>> Starting '$ServiceName' service..."
& $nssm start $ServiceName
Start-Sleep -Seconds 5

$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') {
    Write-Host "Service is Running."
} else {
    Write-Warning "Service did not reach Running state. Check $LogDir for details."
}

# ---------------------------------------------------------------------------
# Step 7 - Sanity check: confirm the gateway HTTP endpoint responds
# ---------------------------------------------------------------------------
Write-Host ">>> Waiting for gateway to accept connections on port $GatewayPort..."
$deadline = (Get-Date).AddSeconds(90)
$ok = $false
while ((Get-Date) -lt $deadline) {
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$GatewayPort/chat" `
                                  -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($resp.StatusCode -lt 500) { $ok = $true; break }
    } catch { }
    Start-Sleep -Seconds 3
}

if ($ok) {
    Write-Host "Gateway responded on http://127.0.0.1:$GatewayPort/chat"
} else {
    Write-Warning "Gateway did not respond within 90s. Inspect $LogDir\gateway.err.log."
}

Write-Host ""
Write-Host "============================================"
Write-Host " OpenClaw Gateway Windows Service installed"
Write-Host " Service name : $ServiceName"
Write-Host " Startup type : Delayed Automatic (auto-restart on crash)"
Write-Host " Run as       : $(if ($RunAsUser) { ".\$RunAsUser" } else { 'LocalSystem' })"
Write-Host " Logs         : $LogDir"
Write-Host " Chat URL     : http://127.0.0.1:$GatewayPort/chat"
Write-Host "============================================"
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  Get-Service $ServiceName"
Write-Host "  nssm restart $ServiceName"
Write-Host "  nssm edit    $ServiceName    # GUI editor"
Write-Host "  nssm remove  $ServiceName confirm"
