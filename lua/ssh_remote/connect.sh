#!/usr/bin/env bash
# =============================================================================
# connect.sh — runs inside the Neovim floating terminal
#
# Usage: bash connect.sh <host-alias> <bootstrap-script-path> [--skip-bootstrap]
#
# Uses SSH ControlMaster so the user only enters their password once.
# The master connection handles auth; scp and the interactive session
# both reuse the same socket.
# =============================================================================

ALIAS="$1"
BOOTSTRAP="$2"
SKIP_BOOTSTRAP="$3"

REMOTE_SCRIPT="/tmp/nvim_bootstrap_$$.sh"
SOCKET="/tmp/ssh_nvim_$(echo "$ALIAS" | tr -cs 'a-zA-Z0-9' '_').sock"

# ── colours ──────────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

cleanup() {
  # Kill the master process and remove the socket
  ssh -S "$SOCKET" -O exit "$ALIAS" 2>/dev/null || true
  rm -f "$SOCKET"
}
trap cleanup EXIT

echo ""
echo -e "${BOLD}  Connecting to ${ALIAS}...${NC}"
echo ""

# =============================================================================
# Step 1 — open master connection
# This is the only point where a password / passphrase prompt can appear.
# -o StrictHostKeyChecking=accept-new  accepts new host keys automatically
#                                      but will not silently accept changed ones.
# =============================================================================
if ! ssh -M -S "$SOCKET" \
         -o ControlPersist=120s \
         -o StrictHostKeyChecking=accept-new \
         "$ALIAS" true; then
  echo ""
  echo -e "${RED}  ✗ Could not connect to ${ALIAS}.${NC}"
  echo "    Check the host is reachable and your credentials are correct."
  echo ""
  exit 1
fi

echo -e "${GREEN}  ✓ Connected${NC}"
echo ""

if [ "$SKIP_BOOTSTRAP" = "--skip-bootstrap" ]; then
  # Drop straight into an interactive shell
  ssh -t -S "$SOCKET" "$ALIAS"
  exit 0
fi

# =============================================================================
# Step 2 — copy the bootstrap script (reuses the master socket, no re-auth)
# =============================================================================
if ! scp -q -o "ControlPath=$SOCKET" "$BOOTSTRAP" "${ALIAS}:${REMOTE_SCRIPT}"; then
  echo -e "${RED}  ✗ Failed to copy setup script to remote.${NC}"
  exit 1
fi

# =============================================================================
# Step 3 — run bootstrap interactively, then drop into a live shell
# =============================================================================
ssh -t -S "$SOCKET" "$ALIAS" "bash $REMOTE_SCRIPT; rm -f $REMOTE_SCRIPT; exec \$SHELL -l"
