#!/usr/bin/env bash
set -Eeuo pipefail

UV_INSTALL_SHA256="f2217f2fe451df47895a580143e2707b59c995186b47dfaa2e92b1aedf0dc764"
NVM_INSTALL_VERSION="v0.40.1"
NVM_INSTALL_SHA256="abdb525ee9f5b48b34d8ed9fc67c6013fb0f659712e401ecd88ab989b3af8f53"
HERMES_INSTALL_SHA256="dbd9d555ed4ac67bd1fc71ba6a39b410cf2af0ebcfd8f4889e086af78c9ddcaa"

# Runtime values injected by muthr at execution time:
#   MUTHR_OPENAI_URL      http://host.lima.internal:8080/v1
#   MUTHR_MODEL_NAME      01-qwen3-6-35b-a3b

OPENAI_URL="${MUTHR_OPENAI_URL:-http://host.lima.internal:8080/v1}"
MODEL_NAME="${MUTHR_MODEL_NAME:-01-qwen3-6-35b-a3b}"

echo "[PROC] Commencing Hermes Agent workspace provision for target VM..."

if test -f "$HOME/.muthr_provision.lock" 2>/dev/null; then
    echo "[WARN] Hermes stack tracking indicates environment is already prepared. Skipping."
    exit 0
fi

echo "[PROC] Installing Python and uv package manager..."
curl -fsSL "https://astral.sh/uv/install.sh" -o /tmp/uv-install.sh
echo "${UV_INSTALL_SHA256}  /tmp/uv-install.sh" | sha256sum -c -
sh /tmp/uv-install.sh
rm -f /tmp/uv-install.sh

echo "[PROC] Installing Node.js v22 via NVM..."
curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_INSTALL_VERSION}/install.sh" -o /tmp/nvm-install.sh
echo "${NVM_INSTALL_SHA256}  /tmp/nvm-install.sh" | sha256sum -c -
bash /tmp/nvm-install.sh
rm -f /tmp/nvm-install.sh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 22
nvm alias default 22

echo "[PROC] Installing Hermes Agent from official installer..."
curl -fsSL "https://hermes-agent.nousresearch.com/install.sh" -o /tmp/hermes-install.sh
echo "${HERMES_INSTALL_SHA256}  /tmp/hermes-install.sh" | sha256sum -c -
bash /tmp/hermes-install.sh
rm -f /tmp/hermes-install.sh

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
