# ---------------------------------------------------------------------------
# install-openclaw.ps1
# Runs inside the Azure Windows 11 VM to install all OpenClaw dependencies.
# Can be executed via:
#   az vm run-command invoke ... --scripts @install-openclaw.ps1
# or manually inside an RDP session.
# ---------------------------------------------------------------------------

# Step 1 – Install Chocolatey
Write-Host ">>> Installing Chocolatey..."
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = `
    [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString(
    'https://community.chocolatey.org/install.ps1'))

# Step 2 – Install Git
Write-Host ">>> Installing Git..."
C:\ProgramData\chocolatey\bin\choco.exe install git -y

# Step 3 – Install C++ build tools (required by native npm modules)
Write-Host ">>> Installing C++ build tools..."
C:\ProgramData\chocolatey\bin\choco.exe install cmake `
    visualstudio2022buildtools `
    visualstudio2022-workload-vctools -y

# Step 4 – Refresh PATH and install Node.js LTS
Write-Host ">>> Installing Node.js LTS..."
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + `
    ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
C:\ProgramData\chocolatey\bin\choco.exe install nodejs-lts -y

# Step 5 – Refresh PATH and install OpenClaw globally
Write-Host ">>> Installing OpenClaw..."
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + `
    ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
npm install -g openclaw

# Step 6 – Ensure Node/npm paths are permanently in system PATH
Write-Host ">>> Updating system PATH..."
$npmGlobalPath  = 'C:\Program Files\nodejs'
$npmUserPath    = [System.Environment]::GetFolderPath('ApplicationData') + '\npm'
$currentPath    = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')

if ($currentPath -notlike "*$npmGlobalPath*") {
    $newPath = $currentPath + ';' + $npmGlobalPath
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')
    Write-Host "Added Node.js path to system PATH"
}
if ($currentPath -notlike "*$npmUserPath*") {
    $newPath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + $npmUserPath
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')
    Write-Host "Added npm global path to system PATH"
}

# Step 7 – Verify
Write-Host ">>> Verifying installations..."
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + `
    ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
Write-Host "Node.js version:" ; node --version
Write-Host "npm version:"    ; npm --version
Write-Host "openclaw:"       ; npm list -g openclaw

Write-Host ""
Write-Host "============================================"
Write-Host " All dependencies and OpenClaw installed!"
Write-Host " Connect via RDP and run: openclaw onboard"
Write-Host "============================================"
