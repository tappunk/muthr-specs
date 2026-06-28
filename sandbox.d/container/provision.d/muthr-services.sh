#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

CONTAINER_ID="${1:-muthr-services}"

echo "[PROC] muthr-services container provisioning - mcp-searxng bridge"

export DEBIAN_FRONTEND=noninteractive
MCP_SEARXNG_VERSION="1.7.2"

MCP_DIR="$HOME/.local"
SEARXNG_URL="${MUTHR_SEARXNG_URL:?MUTHR_SEARXNG_URL is required}"
LOCK_FILE="$HOME/.muthr_provision.lock"
ENV_FINGERPRINT="muthr-services|${SEARXNG_URL}|${MCP_SEARXNG_VERSION}"

if [[ -f "$LOCK_FILE" ]] && [[ "$(cat "$LOCK_FILE" 2>/dev/null || true)" == "$ENV_FINGERPRINT" ]]; then
  echo "[INFO] environment already up to date with this target configuration profile."
  exit 0
fi

cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    rm -f "$LOCK_FILE"
  fi
}
trap cleanup EXIT

echo "[PROC] Ensuring mcp-searxng is installed..."
if [ ! -f "${MCP_DIR}/lib/node_modules/mcp-searxng/dist/cli.js" ]; then
  echo "[PROC] Installing mcp-searxng..."
  mkdir -p "${MCP_DIR}/lib"
  npm install -g --prefix "${MCP_DIR}" --yes "mcp-searxng@${MCP_SEARXNG_VERSION}"
fi

if [ ! -f "$HOME/mcp-stdio.sh" ]; then
  echo "[PROC] Creating mcp-stdio.sh for stdio bridge..."
  printf '%s\n' \
    '#!/bin/bash' \
    'set -euo pipefail' \
    "exec bash -l -c 'SEARXNG_URL=${SEARXNG_URL} node ${MCP_DIR}/lib/node_modules/mcp-searxng/dist/cli.js --stdio'" \
    > "$HOME/mcp-stdio.sh"
  chmod +x "$HOME/mcp-stdio.sh"
fi

if ! grep -qF 'mcp-searxng PATH' "$HOME/.zshenv" 2>/dev/null; then
  {
    printf '\n# mcp-searxng PATH\n'
    printf 'export PATH="$HOME/.local/bin:$PATH"\n'
  } >> "$HOME/.zshenv"
fi

printf '%s\n' "$ENV_FINGERPRINT" > "$LOCK_FILE"
chmod 600 "$LOCK_FILE"

echo "[ OK ] muthr-services container provisioning complete"
