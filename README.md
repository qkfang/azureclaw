# azureclaw

Bicep templates and scripts to deploy [OpenClaw](https://openclaw.ai) — a self-hosted, always-on personal AI agent runtime — on an Azure Windows 11 VM accessible via RDP. See [guide.md](guide.md) for the full step-by-step deployment guide.

## What this repo deploys

Running `bicep/deploy.ps1` (or `scripts/deploy-windows-vm.sh`) provisions the following Azure resources via `bicep/main.bicep`:

- **Virtual network** with a single subnet
- **Network security group** allowing inbound RDP (3389)
- **Public IP address** (Standard SKU, static)
- **Network interface** attached to the subnet and public IP
- **Windows 11 Pro virtual machine** (default size `Standard_D4s_v5`)

## Repository layout

```
├── bicep/
│   ├── main.bicep          # Bicep template (VNet, NSG, VM, public IP)
│   ├── main.bicepparam     # Default parameters
│   └── deploy.ps1          # Sample az deployment commands
├── scripts/
│   ├── deploy-windows-vm.sh          # Deploys Bicep + installs deps via run-command
│   ├── install-openclaw.ps1          # Installs Chocolatey, Git, build tools, Node.js, OpenClaw
│   └── install-openclaw-service.ps1  # Registers `openclaw gateway` as a Windows service via NSSM
└── guide.md                # Full step-by-step deployment guide
```

## Extras

- `scripts/install-openclaw-service.ps1` wraps the OpenClaw gateway as an auto-starting Windows service (via NSSM), so it survives reboots without a logged-in session.
- See `guide.md` for prerequisites, cost estimates, security recommendations, and cleanup instructions.
