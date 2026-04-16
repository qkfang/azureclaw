#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# deploy-windows-vm.sh
# Deploys the Windows 11 VM Bicep template then installs OpenClaw and its
# dependencies inside the VM via az vm run-command.
# ---------------------------------------------------------------------------
set -euo pipefail

###############################################################################
# Configuration — edit these or export them before running the script
###############################################################################
RG="${RG:-rg-openclaw-win}"
LOCATION="${LOCATION:-westus2}"
ADMIN_USERNAME="${ADMIN_USERNAME:-clawadmin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:?Please export ADMIN_PASSWORD before running this script}"

BICEP_FILE="$(cd "$(dirname "$0")/../../bicep/windows-vm" && pwd)/main.bicep"
PARAM_FILE="$(cd "$(dirname "$0")/../../bicep/windows-vm" && pwd)/main.bicepparam"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

###############################################################################
# Resource Group
###############################################################################
echo "==> Creating resource group ${RG} in ${LOCATION}..."
az group create -n "${RG}" -l "${LOCATION}" -o none

###############################################################################
# Deploy Bicep template
###############################################################################
echo "==> Deploying Windows 11 VM Bicep template..."
az deployment group create \
  -g "${RG}" \
  --template-file "${BICEP_FILE}" \
  --parameters "${PARAM_FILE}" \
  --parameters adminPassword="${ADMIN_PASSWORD}" \
  -o none

###############################################################################
# Retrieve outputs
###############################################################################
VM_NAME="$(az deployment group show -g "${RG}" -n main --query 'properties.outputs.vmName.value' -o tsv)"
PUBLIC_IP="$(az deployment group show -g "${RG}" -n main --query 'properties.outputs.publicIpAddress.value' -o tsv)"

echo ""
echo "==> VM deployed. Public IP: ${PUBLIC_IP}"

###############################################################################
# Install dependencies inside the VM via run-command
###############################################################################
echo "==> Installing Chocolatey..."
az vm run-command invoke -g "${RG}" -n "${VM_NAME}" --command-id RunPowerShellScript \
  --scripts @"${SCRIPT_DIR}/install-openclaw.ps1" \
  -o none

###############################################################################
# Verify installation
###############################################################################
echo "==> Verifying installations inside the VM..."
az vm run-command invoke -g "${RG}" -n "${VM_NAME}" --command-id RunPowerShellScript \
  --scripts '
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
Write-Host "Node.js version:"; node --version
Write-Host "npm version:"; npm --version
Write-Host "openclaw:"; npm list -g openclaw
'

echo ""
echo "============================================"
echo " Deployment completed!"
echo "============================================"
echo " Resource Group : ${RG}"
echo " VM Name        : ${VM_NAME}"
echo " Public IP      : ${PUBLIC_IP}"
echo " Admin Username : ${ADMIN_USERNAME}"
echo ""
echo " Connect via RDP: mstsc /v:${PUBLIC_IP}"
echo "============================================"
