![muthr-specs](https://raw.githubusercontent.com/tappunk/.github/refs/heads/main/assets/muthr-specs.webp)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![X Follow](https://img.shields.io/twitter/follow/tappunk?style=social)](https://x.com/tappunk)

# muthr-specs

**Runtime profiles, sandbox manifests, provision scripts, and client config templates for muthr.**

[Installation](#installation) • [Quick Start](#quick-start) • [Structure](#structure) • [Profiles](#profiles) • [Lima Templates](#lima-templates) • [Provision Scripts](#provision-scripts) • [Adding a New Profile](#adding-a-new-profile)

## What is this?

This repo is the configuration package for [muthr](https://github.com/tappunk/muthr). It contains Lima VM templates, profile-specific provision scripts, inference presets, and client configuration templates. When you run `muthr init`, it clones these configs into `~/.config/muthr/`.

## Features

- **Lima VM templates** — Debian 13 with vz VM type, workspace mounts, and pinned image digests
- **Profile provision scripts** — install and configure agent runtimes inside sandbox VMs
- **Client config templates** — reference configs for OpenCode and Hermes Agent
- **llama.cpp presets** — context size, threading, GPU layer, and cache tuning profiles
- **muthr-services manifest** — persistent VM definition for MCP server and SearXNG
- **Profile resolution** — per-profile manifests override the base template with resource overrides

## Installation

muthr-specs is not installed directly. Deploy it with muthr:

```bash
muthr init                   # Clone configs into ~/.config/muthr/
```

To use a custom specs repo:

```bash
muthr init --git-url https://github.com/custom/muthr-specs.git
```

## Quick Start

```bash
muthr init                   # Deploy runtime profiles
muthr run                    # Start inference engine + muthr-services VM
muthr sandbox start          # Create a sandbox for the current project
```

## Structure

```
muthr-specs/
├── base-sandbox.yaml           ← Shared Lima template (Debian 13, vz, mounts, base provision)
├── manifests/
│   ├── base/debian-vz.yaml     ← Base manifest used for sandbox profile resolution
│   └── muthr-services.yaml     ← Persistent muthr-services VM manifest (SearXNG + MCP)
├── provider.d/llama-cpp/       ← llama.cpp preset profiles (INI format)
│   ├── bw150g-qwen3.5-9b.ini
│   └── bw600g-qwen3.6-35b-a3b.ini
├── provision.d/                ← Profile-specific provision scripts
│   ├── lib/provision-lib.sh    ← Shared shell helpers
│   ├── muthr-services.sh       ← Installs SearXNG and mcp-searxng
│   ├── opencode.sh             ← Installs opencode, MCP servers, generates config
│   └── hermes-agent.sh         ← Installs Hermes Agent with local engine config
├── clients/                    ← Client config templates (reference only)
│   ├── opencode.json           ← OpenCode AI config template
│   └── hermes-agent.yaml       ← Hermes Agent config template
└── LICENSE
```

## Profiles

muthr resolves profiles from the `provision.d/` directory. Each profile name corresponds to a shell script.

### base

Minimal Debian 13 VM with shell access only. Installs base development tools (git, curl, neovim, nodejs, python3). No agent runtime — useful for custom setups.

### opencode

Full opencode AI workspace setup. Installs the opencode CLI, MCP servers (memory, filesystem, OpenAI-compatible), generates the opencode runtime config using muthr env vars, and drops into an opencode session.

### hermes-agent

Hermes Agent installation. Sets up nvm, installs the Hermes Agent runtime, configures it to connect to the host inference engine, and drops into a shell.

### muthr-services

Persistent services VM. Runs SearXNG (web search) and mcp-searxng (MCP tool for search). Provisioned once and stays running until `muthr shutdown`. Exposes port 18766 for the web UI and port 18765 for the MCP server.

## Lima Templates

### base-sandbox.yaml

The shared foundation for all sandbox profiles. Defines Debian 13 with vz VM type, workspace mounts using `__WORKSPACE_ROOT__` and `__MOUNT_POINT__` placeholders, and inline system provision for base packages.

muthr substitutes the placeholders with the actual workspace path before creating the VM. If a profile has its own YAML manifest (e.g. `opencode.yaml`), muthr uses that first, falling back to `base-sandbox.yaml` for any undefined fields.

### Template defaults

All Lima templates in this repo follow these conventions:

- Pin the Debian 13 image with a SHA512 digest
- Use `vmType: "vz"`, `mountType: "virtiofs"`
- Disable `ssh.forwardAgent`
- Enable `hostResolver` with IPv6 disabled
- Set `containerd.user: true` for containerized services

Profile-specific manifests are optional — create `<profile>.yaml` only if you need different CPU, memory, or disk resources.

## Provision Scripts

Scripts in `provision.d/` are copied into sandbox VMs via `limactl cp` and executed by muthr during sandbox creation. They receive runtime environment variables injected by muthr at execution time.

### Environment variables

| Variable                | Example                             | Description                                   |
| ----------------------- | ----------------------------------- | --------------------------------------------- |
| `MUTHR_OPENAI_URL`      | `http://host.lima.internal:8080/v1` | Inference engine endpoint (OpenAI-compatible) |
| `MUTHR_MODEL_NAME`      | `01-qwen3-6-35b-a3b`                | Model identifier from the active preset       |
| `MUTHR_CTX_WINDOW`      | `262144`                            | Context window size                           |
| `MUTHR_WORKSPACE_MOUNT` | `/muthr-project1`                   | Workspace path inside the VM                  |

Provision scripts use these variables to generate native client configs and install applications that connect to the host inference engine.

### Script conventions

- Use `set -Eeuo pipefail` and `export DEBIAN_FRONTEND=noninteractive`
- Check for `~/.muthr_provision.lock` to skip re-provisioning
- Write configs to native app locations (e.g. `~/.opencode/opencode.json`)
- Place shared helpers in `provision.d/lib/provision-lib.sh`

## Adding a New Profile

1. Create `provision.d/<profile>.sh` — installs the application and generates its native config using the muthr env vars above
2. Optionally create `<profile>.yaml` if you need different VM resources (cpus, memory, disk)
3. Optionally add a config template to `clients/` as a reference for other contributors
