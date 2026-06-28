#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# shellcheck source=sandbox.d/container/provision.d/lib/provision-lib.sh
source "$(dirname "$0")/lib/provision-lib.sh"

PROFILE_REV="2026-06-28.6"

# Runtime values injected by muthr at execution time:
#   MUTHR_OPENAI_URL      http://<backend-gateway>:8080/v1
#   MUTHR_MODEL_NAME      01-qwen3-6-35b-a3b
#   MUTHR_CTX_WINDOW      262144
#   MUTHR_WORKSPACE_MOUNT /workspace
#   MUTHR_SPECS_REV       sha256 of provision script content
#   MUTHR_CONTAINER_HOST_GATEWAY container host bridge gateway
#   MUTHR_SEARXNG_URL      http://<container-gateway>:18766

OPENAI_URL="${MUTHR_OPENAI_URL:?MUTHR_OPENAI_URL is required}"
MODEL_NAME="${MUTHR_MODEL_NAME:?MUTHR_MODEL_NAME is required}"
CTX_WINDOW="${MUTHR_CTX_WINDOW:?MUTHR_CTX_WINDOW is required}"
WORKSPACE_MOUNT="${MUTHR_WORKSPACE_MOUNT:-/workspace}"
CONTAINER_HOST_GATEWAY="${MUTHR_CONTAINER_HOST_GATEWAY:?MUTHR_CONTAINER_HOST_GATEWAY is required}"
SEARXNG_URL="${MUTHR_SEARXNG_URL:?MUTHR_SEARXNG_URL is required}"

echo "[PROC] Commencing opencode workspace provision for target container..."

_lib_init_provision_state "opencode" "$PROFILE_REV" "$OPENAI_URL" "$MODEL_NAME" "$CTX_WINDOW" "$WORKSPACE_MOUNT"

export DEBIAN_FRONTEND=noninteractive
if ! command -v npm &>/dev/null; then
    sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq && \
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs npm
fi

echo "[PROC] Installing OpenAI-compatible provider package..."
sudo npm install -g --loglevel=silent --yes \
    "@ai-sdk/openai-compatible"

echo "[PROC] Installing SearXNG MCP server package..."
sudo npm install -g --loglevel=silent --yes mcp-searxng

echo "[PROC] Installing Astral UV package manager..."
curl -LsSf "https://astral.sh/uv/install.sh" | sh
if [ -x "$HOME/.local/bin/uvx" ]; then
    sudo ln -sf "$HOME/.local/bin/uv" /usr/local/bin/uv
    sudo ln -sf "$HOME/.local/bin/uvx" /usr/local/bin/uvx
fi

echo "[PROC] Installing OpenCode CLI..."
curl -fsSL "https://opencode.ai/install" | bash
if [ -x "$HOME/.opencode/bin/opencode" ]; then
    sudo ln -sf "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode
elif [ -x "$HOME/.local/bin/opencode" ]; then
    sudo ln -sf "$HOME/.local/bin/opencode" /usr/local/bin/opencode
fi

echo "[PROC] Generating OpenCode configuration..."
mkdir -p "$HOME/.opencode"

cat > "$HOME/.opencode/opencode.json" << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "model": "mlxcel/${MODEL_NAME}",
  "small_model": "mlxcel/${MODEL_NAME}",
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
    "CRITICAL ENV CONTEXT: You are running inside an isolated sandbox container (Debian 13 guest).",
    "Your home directory config files are strictly inside /home/user.guest/, and your project workspace is mounted at /workspace.",
    "Always run file and tool operations relative to /workspace or its subdirectories."
  ],

  "compaction": {
    "auto": true,
    "prune": false,
    "reserved": 16384,
    "tail_turns": 6
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
    "mlxcel": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "mlxcel (container)",
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
      "command": ["npx", "-y", "@modelcontextprotocol/server-memory"],
      "enabled": true
    },
    "fetch": {
      "type": "local",
      "command": ["uvx", "mcp-server-fetch"],
      "enabled": false
    },
    "filesystem": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "${WORKSPACE_MOUNT}"],
      "enabled": true
    },
    "searxng": {
      "type": "local",
      "command": ["mcp-searxng", "--stdio"],
      "enabled": true,
      "environment": {
        "SEARXNG_URL": "${SEARXNG_URL}"
      }
    }
  },

  "agent": {
    "plan": {
      "mode": "primary",
      "model": "mlxcel/${MODEL_NAME}"
    },
    "build": {
      "mode": "primary",
      "model": "mlxcel/${MODEL_NAME}"
    },
    "review": {
      "mode": "subagent",
      "model": "mlxcel/${MODEL_NAME}",
      "tools": {
        "write": true,
        "edit": true,
        "bash": true
      }
    },
    "explore": {
      "mode": "subagent",
      "model": "mlxcel/${MODEL_NAME}",
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

chmod 700 "$HOME/.opencode"
chmod 600 "$HOME/.opencode/opencode.json"

_lib_finalize_provision_state

echo "[ OK ] Opencode environment initialized successfully."
echo ""
echo "   Model:        ${MODEL_NAME}"
echo "   Context:      ${CTX_WINDOW} tokens"
echo "   Engine URL:   ${OPENAI_URL}"
echo "   Workspace:    ${WORKSPACE_MOUNT}"
echo "   Gateway:      ${CONTAINER_HOST_GATEWAY}"
