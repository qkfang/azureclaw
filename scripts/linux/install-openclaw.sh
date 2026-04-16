#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# install-openclaw.sh
# Run this script **inside** the Azure Linux VM (via Bastion SSH) to install
# OpenClaw and start the onboarding wizard.
# ---------------------------------------------------------------------------
set -euo pipefail

echo "==> Installing OpenClaw..."
curl -fsSL https://openclaw.ai/install.sh | bash

echo ""
echo "==> OpenClaw installed. Verifying..."
openclaw status        || true
openclaw gateway status || true

echo ""
echo "============================================"
echo " OpenClaw is installed!"
echo " Run 'openclaw doctor' if you see any issues."
echo "============================================"
