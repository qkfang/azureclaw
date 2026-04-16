# OpenClaw on Azure — Step-by-Step Deployment Guide

This guide walks you through deploying [OpenClaw](https://openclaw.ai) on Azure Virtual Machines using the Bicep templates and scripts in this repository. Two deployment paths are covered:

| Path | OS | Access method | Security model |
|------|----|---------------|----------------|
| **Option A** | Ubuntu 24.04 LTS | Azure Bastion SSH (no public IP) | NSG-hardened, Bastion-only SSH |
| **Option B** | Windows 11 Pro | RDP via public IP | NSG with RDP rule |

> **What is OpenClaw?** A self-hosted, always-on personal AI agent runtime. You bring your own model provider (GitHub Copilot, Azure OpenAI, OpenAI, Anthropic Claude, Google Gemini, etc.) and interact with the agent through channels like Microsoft Teams, Slack, Telegram, or WhatsApp.

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Azure subscription | Permission to create compute and network resources |
| Azure CLI | [Install guide](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| SSH key pair (Linux path only) | The deploy script generates one if missing |
| Time | ~20–30 min (Linux may take longer because Bastion provisioning can take up to 30 min) |

---

## Repository Layout

```
├── bicep/
│   ├── linux-vm/
│   │   ├── main.bicep          # Bicep template (VNet, NSG, VM, Bastion)
│   │   └── main.bicepparam     # Default parameters
│   └── windows-vm/
│       ├── main.bicep          # Bicep template (VNet, NSG, VM, public IP)
│       └── main.bicepparam     # Default parameters
├── scripts/
│   ├── linux/
│   │   ├── deploy-linux-vm.sh      # Deploys Bicep + connects via Bastion
│   │   └── install-openclaw.sh     # Runs inside the VM to install OpenClaw
│   └── windows/
│       ├── deploy-windows-vm.sh    # Deploys Bicep + installs deps via run-command
│       └── install-openclaw.ps1    # PowerShell script executed inside the VM
└── guide.md                        # This file
```

---

## Option A — Linux VM (Ubuntu 24.04 LTS)

### Step 1: Log in to Azure

```bash
az login
az extension add -n ssh        # Required for Bastion SSH tunneling
```

### Step 2: Register Resource Providers (one-time)

```bash
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
```

Verify both show **Registered**:

```bash
az provider show --namespace Microsoft.Compute --query registrationState -o tsv
az provider show --namespace Microsoft.Network --query registrationState -o tsv
```

### Step 3: Review & Customise Configuration

Edit variables at the top of `scripts/linux/deploy-linux-vm.sh` or export them:

| Variable | Default | Description |
|----------|---------|-------------|
| `RG` | `rg-openclaw` | Resource group name |
| `LOCATION` | `westus2` | Azure region |
| `ADMIN_USERNAME` | `openclaw` | VM admin username |
| `SSH_KEY_PATH` | `~/.ssh/id_ed25519` | Path to SSH private key |

You can also edit `bicep/linux-vm/main.bicepparam` to change VM size, disk size, or networking CIDRs.

### Step 4: Deploy

```bash
chmod +x scripts/linux/deploy-linux-vm.sh
./scripts/linux/deploy-linux-vm.sh
```

The script will:

1. Create the resource group.
2. Deploy the Bicep template (VNet, subnets, NSG, VM, Bastion).
3. Automatically connect to the VM via Azure Bastion SSH.

> **Note:** Bastion provisioning can take 5–30 minutes.

### Step 5: Install OpenClaw (inside the VM)

Once the Bastion SSH session opens, run:

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

Or copy the helper script into the VM and run it:

```bash
bash install-openclaw.sh
```

The installer will:
- Install Node.js LTS and dependencies if not already present.
- Install OpenClaw.
- Launch the **OpenClaw onboarding wizard**.

### Step 6: Choose Your AI Model Provider

During onboarding, select your provider:

- **GitHub Copilot** (recommended if your org already has licenses)
- Azure OpenAI
- OpenAI
- Anthropic Claude
- Google Gemini
- Other supported providers

See [OpenClaw provider docs](https://docs.openclaw.ai/providers/github-copilot) for details.

### Step 7: Set Up Messaging Channels (optional)

Connect one or more channels:

- Telegram (easiest for first-time setup)
- Microsoft Teams
- Slack
- WhatsApp

See [OpenClaw channels docs](https://docs.openclaw.ai/channels).

### Step 8: Verify

```bash
openclaw status
openclaw gateway status
```

If issues appear, run:

```bash
openclaw doctor
```

---

## Option B — Windows 11 Pro VM

### Step 1: Log in to Azure

```bash
az login
```

### Step 2: Review & Customise Configuration

Edit variables at the top of `scripts/windows/deploy-windows-vm.sh` or export them:

| Variable | Default | Description |
|----------|---------|-------------|
| `RG` | `rg-openclaw-win` | Resource group name |
| `LOCATION` | `westus2` | Azure region |
| `ADMIN_USERNAME` | `clawadmin` | VM admin username |
| `ADMIN_PASSWORD` | *(must be set)* | VM admin password (export before running) |

> **Security:** Never commit real passwords. Export `ADMIN_PASSWORD` in your terminal session:
> ```bash
> export ADMIN_PASSWORD='YourStr0ng!Passw0rd'
> ```

You can also edit `bicep/windows-vm/main.bicepparam` to change VM size or networking CIDRs.

### Step 3: Deploy

```bash
chmod +x scripts/windows/deploy-windows-vm.sh
./scripts/windows/deploy-windows-vm.sh
```

The script will:

1. Create the resource group.
2. Deploy the Bicep template (VNet, NSG, VM with public IP).
3. Install Chocolatey, Git, C++ build tools, Node.js LTS, and OpenClaw inside the VM via `az vm run-command`.
4. Verify all installations and print the public IP.

### Step 4: Connect via RDP

**Windows:**

```
mstsc /v:<PUBLIC_IP>
```

**macOS:** Download *Windows App* from the App Store, add a PC with the public IP.

**Linux:**

```bash
xfreerdp /u:clawadmin /v:<PUBLIC_IP>
```

### Step 5: Onboard OpenClaw (inside the VM)

Open PowerShell or Command Prompt in the RDP session:

```powershell
openclaw onboard
```

Follow the wizard to choose your AI model provider and (optionally) connect messaging channels.

### Step 6: Configure the AI Model API Key

Edit the configuration file:

```powershell
notepad $env:USERPROFILE\.openclaw\openclaw.json
```

Add your API key:

```json
{
  "agents": {
    "defaults": {
      "model": "Your Model Name",
      "apiKey": "your-api-key-here"
    }
  }
}
```

### Step 7: Start OpenClaw

```powershell
# Start the gateway service
openclaw gateway

# In another terminal, connect messaging channels
openclaw channels login
```

Follow the prompts (e.g., scan a QR code) to link your messaging app.

### Step 8: Verify

```powershell
openclaw status
openclaw gateway status
```

---

## Cleanup

Delete all resources when you're done:

**Linux deployment:**

```bash
az group delete -n rg-openclaw --yes --no-wait
```

**Windows deployment:**

```bash
az group delete -n rg-openclaw-win --yes --no-wait
```

This removes the resource group and everything inside it (VM, VNet, NSG, Bastion, public IP, etc.).

---

## Cost Estimates

| VM SKU | Approx. cost | Notes |
|--------|-------------|-------|
| Standard_B2as_v2 (Linux) | ~$0.04/hr | Stop when idle to save costs |
| Standard_B2s (Windows) | ~$0.05/hr | Stop when idle to save costs |

- Consider [Azure Reserved Instances](https://azure.microsoft.com/pricing/reserved-vm-instances/) for up to 72% savings.
- Use the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) for detailed estimates.

---

## Security Recommendations

1. **Linux path:** Uses Azure Bastion — no public IP on the VM.
2. **Windows path:** Consider adding Bastion instead of a public IP for production use.
3. Enable [Just-in-Time VM access](https://learn.microsoft.com/azure/defender-for-cloud/just-in-time-access-usage) in Azure Security Center.
4. Store API keys in [Azure Key Vault](https://azure.microsoft.com/services/key-vault/) instead of configuration files.
5. Keep the OS and OpenClaw up to date.
6. Restrict NSG source IPs to your corporate network where possible.

---

## References

- [OpenClaw on Azure Linux VMs (Microsoft Tech Community)](https://techcommunity.microsoft.com/blog/linuxandopensourceblog/run-openclaw-agents-on-azure-linux-vms-with-secure-defaults/4502944)
- [OpenClaw on Azure Windows 11 VM (Microsoft Tech Community)](https://techcommunity.microsoft.com/blog/azuredevcommunityblog/complete-guide-to-deploying-openclaw-on-azure-windows-11-virtual-machine/4492001)
- [OpenClaw Website](https://openclaw.ai)
- [OpenClaw Docs](https://docs.openclaw.ai)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [Azure CLI Docs](https://docs.microsoft.com/cli/azure/)
