#!/usr/bin/env bash
set -euo pipefail

# Simple usage info
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/private_key"
  exit 1
fi

KEY_PATH="$1"

# Check that the key exists
if [[ ! -f "$KEY_PATH" ]]; then
  echo "Error: key file not found at '$KEY_PATH'"
  exit 1
fi

echo "[*] Starting (or reusing) ssh-agent..."
# Start or attach to an existing agent session
eval "$(ssh-agent -s)"

echo "[*] Adding SSH key: $KEY_PATH"
ssh-add "$KEY_PATH"

echo "[*] Testing SSH connection to GitHub..."
# Use ssh -T (no command execution, test authentication only)
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  echo "[✓] SSH key works with GitHub!"
else
  echo "[!] Could not authenticate to GitHub. Check the key or ssh-agent output."
fi

# Kill the agent (optional, but good housekeeping)
echo "[*] Killing ssh-agent..."
eval "$(ssh-agent -k)" >/dev/null
