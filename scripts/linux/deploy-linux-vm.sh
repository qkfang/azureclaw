#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# deploy-linux-vm.sh
# Deploys the Linux VM Bicep template and connects via Azure Bastion SSH.
# ---------------------------------------------------------------------------
set -euo pipefail

###############################################################################
# Configuration — edit these or export them before running the script
###############################################################################
RG="${RG:-rg-openclaw}"
LOCATION="${LOCATION:-westus2}"
ADMIN_USERNAME="${ADMIN_USERNAME:-openclaw}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"

BICEP_FILE="$(cd "$(dirname "$0")/../../bicep/linux-vm" && pwd)/main.bicep"
PARAM_FILE="$(cd "$(dirname "$0")/../../bicep/linux-vm" && pwd)/main.bicepparam"

###############################################################################
# Pre-flight
###############################################################################
echo "==> Logging in (if needed) and installing SSH extension..."
az extension add -n ssh 2>/dev/null || true

echo "==> Registering required resource providers..."
az provider register --namespace Microsoft.Compute --wait  >/dev/null
az provider register --namespace Microsoft.Network --wait  >/dev/null

###############################################################################
# SSH key
###############################################################################
if [ ! -f "${SSH_KEY_PATH}" ]; then
  echo "==> Generating SSH key pair at ${SSH_KEY_PATH}..."
  ssh-keygen -t ed25519 -a 100 -f "${SSH_KEY_PATH}" -C "openclaw@azure" -N ""
fi
SSH_PUB_KEY="$(cat "${SSH_KEY_PATH}.pub")"

###############################################################################
# Resource Group
###############################################################################
echo "==> Creating resource group ${RG} in ${LOCATION}..."
az group create -n "${RG}" -l "${LOCATION}" -o none

###############################################################################
# Deploy Bicep template
###############################################################################
echo "==> Deploying Bicep template (this may take 10–30 min for Bastion)..."
az deployment group create \
  -g "${RG}" \
  --template-file "${BICEP_FILE}" \
  --parameters "${PARAM_FILE}" \
  --parameters sshPublicKey="${SSH_PUB_KEY}" \
  -o none

###############################################################################
# Retrieve outputs
###############################################################################
VM_ID="$(az deployment group show -g "${RG}" -n main --query 'properties.outputs.vmId.value' -o tsv)"
BASTION_NAME="$(az deployment group show -g "${RG}" -n main --query 'properties.outputs.bastionName.value' -o tsv)"
VM_NAME="$(az deployment group show -g "${RG}" -n main --query 'properties.outputs.vmName.value' -o tsv)"

echo ""
echo "============================================"
echo " Deployment complete!"
echo "============================================"
echo " Resource Group : ${RG}"
echo " VM Name        : ${VM_NAME}"
echo " Bastion        : ${BASTION_NAME}"
echo " Admin User     : ${ADMIN_USERNAME}"
echo "============================================"
echo ""

###############################################################################
# Connect via Bastion SSH
###############################################################################
echo "==> Connecting to the VM via Azure Bastion SSH..."
echo "    (Once connected, run: bash /tmp/install-openclaw.sh  or"
echo "     curl -fsSL https://openclaw.ai/install.sh | bash )"
echo ""

az network bastion ssh \
  --name "${BASTION_NAME}" \
  --resource-group "${RG}" \
  --target-resource-id "${VM_ID}" \
  --auth-type ssh-key \
  --username "${ADMIN_USERNAME}" \
  --ssh-key "${SSH_KEY_PATH}"
