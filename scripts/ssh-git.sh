#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------
# ssh-git: Setup temporary SSH agent and test GitHub authentication
# ---------------------------------------------

show_help() {
  cat <<EOF
Usage: $0 /path/to/private_key

Description:
  Starts (or reuses) an ssh-agent, adds the given SSH private key,
  tests authentication to GitHub, then shuts down the agent.

Options:
  -h, --help     Show this help message and exit

Examples:
  $0 ~/.ssh/id_ed25519
EOF
}

# ---------------------------------------------
# Argument check and help
# ---------------------------------------------

if [[ $# -eq 0 ]]; then
  echo "Error: Missing argument."
  echo "Usage: $0 /path/to/private_key"
  exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
  exit 0
fi

KEY_PATH="$1"

# ---------------------------------------------
# Validate key path
# ---------------------------------------------
if [[ ! -f "$KEY_PATH" ]]; then
  echo "Error: key file not found at '$KEY_PATH'"
  exit 1
fi

# ---------------------------------------------
# Start and manage ssh-agent
# ---------------------------------------------
if ! pgrep ssh-agent >/dev/null; then
  echo "[*] Starting new ssh-agent..."
  eval "$(ssh-agent -s)"
else
  echo "[*] Reusing existing ssh-agent..."
fi

echo "[*] Adding SSH key: $KEY_PATH"
ssh-add "$KEY_PATH"

# ---------------------------------------------
# Test GitHub authentication
# ---------------------------------------------
echo "[*] Testing SSH connection to GitHub..."
SSH_OUTPUT=$(ssh -T git@github.com 2>&1 || true)
echo "$SSH_OUTPUT"

if echo "$SSH_OUTPUT" | grep -q "Permission denied (publickey)"; then
  echo "[✗] SSH key authentication failed: Permission denied."
  echo "[!] Verify that your public key is added to your GitHub account and that the correct key is being loaded."
  EXIT_CODE=1
else
  echo "[✓] SSH key appears to work with GitHub!"
  EXIT_CODE=0
fi

# ---------------------------------------------
# Cleanup
# ---------------------------------------------
if [[ "$1" == "-c" || "$1" == "--cleanup" ]]; then
  echo "[*] Killing ssh-agent..."
  eval "$(ssh-agent -k)" >/dev/null
  exit 0
fi

exit $EXIT_CODE