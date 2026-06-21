#!/usr/bin/env bash
set -Eeuo pipefail

# Runtime values injected by muthr at execution time:
#   MUTHR_OPENAI_URL      http://host.lima.internal:8080/v1
#   MUTHR_MODEL_NAME      01-qwen3-6-35b-a3b

OPENAI_URL="${MUTHR_OPENAI_URL:-http://host.lima.internal:8080/v1}"
MODEL_NAME="${MUTHR_MODEL_NAME:-unknown}"

echo "[PROC] Commencing Hermes Agent workspace provision for target VM..."

if test -f "$HOME/.muthr_provision.lock" 2>/dev/null; then
    echo "[WARN] Hermes stack tracking indicates environment is already prepared. Skipping."
    exit 0
fi

echo "[PROC] Installing Python and uv package manager..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "[PROC] Installing Node.js v22 via NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 22
nvm alias default 22

echo "[PROC] Installing Hermes Agent from official installer..."
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

echo "[PROC] Configuring Hermes Agent to use local inference engine..."
mkdir -p "$HOME/.hermes"

cat > "$HOME/.hermes/config.yaml" << EOF
model:
  default: "${MODEL_NAME}"
  provider: "custom"
  base_url: "${OPENAI_URL}"

providers:
  custom:
    request_timeout_seconds: 300

terminal:
  backend: "local"
  cwd: "."
  timeout: 180
  home_mode: "auto"

agent:
  max_turns: 60
  verbose: false

mcp_servers:
  memory:
    command: mcp-server-memory
    args: []
  filesystem:
    command: mcp-server-filesystem
    args: ["${MUTHR_WORKSPACE_MOUNT:-/workspace}"]

session_reset:
  mode: both
  idle_minutes: 1440
EOF

touch "$HOME/.muthr_provision.lock"

echo "[ OK ] Hermes Agent environment initialized successfully."
echo ""
echo "   Model:        ${MODEL_NAME}"
echo "   Engine URL:   ${OPENAI_URL}"
echo "   Config:       ~/.hermes/config.yaml"
