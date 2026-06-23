#!/usr/bin/env bash
set -Eeuo pipefail

OPENCODE_VERSION="v1.17.9"
OPENCODE_TARBALL="opencode-linux-arm64.tar.gz"
OPENCODE_SHA256="8cc511f9794e575e5d3c4c2654930d05670186df649c26b50889ac73c65dde21"
OPENCODE_URL="https://github.com/anomalyco/opencode/releases/download/${OPENCODE_VERSION}/${OPENCODE_TARBALL}"

UV_INSTALL_SHA256="f2217f2fe451df47895a580143e2707b59c995186b47dfaa2e92b1aedf0dc764"

MCP_OPENAI_COMPATIBLE_VERSION="2.0.51"
MCP_MEMORY_VERSION="2026.1.26"
MCP_FILESYSTEM_VERSION="2026.1.14"

# Runtime values injected by muthr at execution time:
#   MUTHR_OPENAI_URL      http://host.lima.internal:8080/v1
#   MUTHR_MODEL_NAME      01-qwen3-6-35b-a3b
#   MUTHR_CTX_WINDOW      262144
#   MUTHR_WORKSPACE_MOUNT /muthr-project1

OPENAI_URL="${MUTHR_OPENAI_URL:-http://host.lima.internal:8080/v1}"
MODEL_NAME="${MUTHR_MODEL_NAME:-01-qwen3-6-35b-a3b}"
CTX_WINDOW="${MUTHR_CTX_WINDOW:-262144}"
WORKSPACE_MOUNT="${MUTHR_WORKSPACE_MOUNT:-/workspace}"

echo "[PROC] Commencing opencode workspace provision for target VM..."

if test -f "$HOME/.muthr_provision.lock" 2>/dev/null; then
    echo "[WARN] Opencode stack tracking indicates environment is already prepared. Skipping."
    exit 0
fi

export DEBIAN_FRONTEND=noninteractive
if ! command -v npm &>/dev/null; then
    sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq && \
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs npm
fi

echo "[PROC] Installing MCP servers (memory + filesystem)..."
sudo npm install -g --loglevel=silent --yes \
    "@ai-sdk/openai-compatible@${MCP_OPENAI_COMPATIBLE_VERSION}" \
    "@modelcontextprotocol/server-memory@${MCP_MEMORY_VERSION}" \
    "@modelcontextprotocol/server-filesystem@${MCP_FILESYSTEM_VERSION}"

echo "[PROC] Deploying Astral UV package manager..."
curl -fsSL "https://astral.sh/uv/install.sh" -o /tmp/uv-install.sh
echo "${UV_INSTALL_SHA256}  /tmp/uv-install.sh" | sha256sum -c -
sudo env UV_INSTALL_DIR='/usr/local/bin' sh /tmp/uv-install.sh
rm -f /tmp/uv-install.sh

echo "[PROC] Installing OpenCode CLI from GitHub releases..."
curl -fsSL -o /tmp/opencode.tar.gz "${OPENCODE_URL}"
echo "${OPENCODE_SHA256}  /tmp/opencode.tar.gz" | sha256sum -c -
sudo tar -xzf /tmp/opencode.tar.gz -C /usr/local/bin/ opencode
rm -f /tmp/opencode.tar.gz

echo "[PROC] Generating OpenCode configuration..."
mkdir -p "$HOME/.opencode"

cat > "$HOME/.opencode/opencode.json" << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "model": "llama-cpp/${MODEL_NAME}",
  "small_model": "llama-cpp/${MODEL_NAME}",
  "autoupdate": false,

  "disabled_providers": [
    "opencode",
    "github-copilot",
    "openai",
    "anthropic",
    "google"
  ],

  "instructions": [
    "If filesystem_edit_file fails, immediately fallback to write_file to replace the entire content.",
    "CRITICAL ENV CONTEXT: You are running inside an isolated sandbox Lima VM (Debian 13 guest).",
    "Your home directory config files are strictly inside /home/user.guest/, but your workspace project is mounted 1-to-1 matching the host architecture paths.",
    "Always perform file tracking and tool tasks relative to your active mounted workspace directory path parameter layout."
  ],

  "compaction": {
    "auto": true,
    "prune": true,
    "reserved": 8192
  },

  "permission": {
    "*": "allow",
    "bash": {
      "rm *": "ask",
      "sudo *": "ask",
      "dd *": "ask",
      "mkfs *": "ask",
      ":() { : | :& }; :": "deny"
    }
  },

  "provider": {
    "llama-cpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama.cpp (lima-vm)",
      "options": {
        "baseURL": "${OPENAI_URL}"
      },
      "models": {
        "${MODEL_NAME}": {
          "name": "${MODEL_NAME}",
          "tools": true,
          "context_window": ${CTX_WINDOW},
          "limit": {
            "context": ${CTX_WINDOW},
            "output": 8192
          }
        }
      }
    }
  },

  "mcp": {
    "memory": {
      "type": "local",
      "command": ["mcp-server-memory"],
      "enabled": true
    },
    "fetch": {
      "type": "local",
      "command": ["uvx", "mcp-server-fetch"],
      "enabled": false
    },
    "filesystem": {
      "type": "local",
      "command": ["mcp-server-filesystem", "${WORKSPACE_MOUNT}"],
      "enabled": true
    },
    "searxng": {
      "type": "local",
      "command": ["npx", "-y", "mcp-searxng", "--stdio"],
      "enabled": true,
      "environment": {
        "SEARXNG_URL": "http://host.lima.internal:18766"
      }
    }
  },

  "agent": {
    "plan": {
      "mode": "primary",
      "model": "llama-cpp/${MODEL_NAME}"
    },
    "build": {
      "mode": "primary",
      "model": "llama-cpp/${MODEL_NAME}"
    },
    "review": {
      "mode": "subagent",
      "model": "llama-cpp/${MODEL_NAME}",
      "tools": {
        "write": true,
        "edit": true,
        "bash": true
      }
    },
    "explore": {
      "mode": "subagent",
      "model": "llama-cpp/${MODEL_NAME}",
      "tools": {
        "write": true,
        "edit": true,
        "bash": true
      }
    }
  },

  "default_agent": "build"
}
EOF

touch "$HOME/.muthr_provision.lock"

echo "[ OK ] Opencode environment initialized successfully."
echo ""
echo "   Model:        ${MODEL_NAME}"
echo "   Context:      ${CTX_WINDOW} tokens"
echo "   Engine URL:   ${OPENAI_URL}"
echo "   Workspace:    ${WORKSPACE_MOUNT}"
