![muthr-specs](https://raw.githubusercontent.com/tappunk/.github/refs/heads/main/assets/muthr-specs.webp)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![X Follow](https://img.shields.io/twitter/follow/tappunk?style=social)](https://x.com/tappunk)

# muthr-specs

Lima templates, provision scripts, and client config templates for [muthr](https://github.com/tappunk/muthr).

> [!NOTE]
> These configs deploy to `~/.config/muthr/` via `muthr init`. You need muthr installed before using these profiles.

## Usage

```bash
# Deploy configs into ~/.config/muthr/
muthr init

# Start inference engine + muthr-services VM
muthr run

# Navigate to a project and create a sandbox
cd ~/src/myproject
muthr sandbox start          # prompts: select profile (base, opencode, hermes-agent)
muthr sandbox start --profile opencode  # explicit: create with opencode profile
muthr sandbox stop        # stop the sandbox VM
muthr sandbox delete      # unprotect → stop → delete → clean cache
```

## Structure

```
muthr-specs/
├── base-sandbox.yaml           ← Shared Lima template (Debian 13, vz, mounts, base provision)
├── manifests/
│   ├── base/debian-vz.yaml     ← Base manifest used for sandbox profile resolution
│   └── muthr-services.yaml     ← Persistent muthr-services VM manifest
├── provision.d/                ← Profile-specific provision scripts (copied + executed by muthr)
│   ├── opencode.sh             ← Opencode AI: installs CLI, MCP servers, generates config, launches
│   ├── muthr-services.sh       ← Installs and configures curated MCP services utilities VM
│   ├── hermes-agent.sh         ← Hermes Agent: installs agent, configures local engine, drops to shell
│   └── lib/provision-lib.sh    ← Shared shell helpers
├── clients/                    ← Client config templates (reference only — provision scripts generate native configs)
│   ├── opencode.json           ← OpenCode AI config template
│   └── hermes-agent.yaml       ← Hermes Agent config template
└── LICENSE
```

## Lima Templates

**`base-sandbox.yaml`** is the shared foundation for all profiles. It defines Debian 13 with vz VM type, workspace mounts (using `__WORKSPACE_ROOT__` and `__MOUNT_POINT__` placeholders), and inline provision for base system packages.

Profile-specific manifests are optional — create `<profile>.yaml` only if you need different resources (cpus/memory/disk). muthr resolves profile-specific YAML first, falling back to `base-sandbox.yaml`.

## Provision Scripts

Scripts in `provision.d/` are copied into VMs via `limactl cp` and executed by muthr. They receive runtime env vars:

| Variable                | Description                                                           |
| ----------------------- | --------------------------------------------------------------------- |
| `MUTHR_OPENAI_URL`      | Inference engine endpoint (e.g., `http://host.lima.internal:8080/v1`) |
| `MUTHR_MODEL_NAME`      | Model identifier from active preset                                   |
| `MUTHR_CTX_WINDOW`      | Context window size                                                   |
| `MUTHR_WORKSPACE_MOUNT` | Workspace path inside VM                                              |

Provision scripts use these to generate native client configs and install their respective applications.

## Adding a New Profile

1. Create `provision.d/<profile>.sh` — installs the app and generates its native config using muthr env vars
2. Optionally create `<profile>.yaml` if you need different VM resources
3. Optionally add a config template to `clients/` as reference

## Vocabulary

- **Lima VM** — virtual machine via Lima (`vmType: vz`)
- **provision script** — bash script copied into VMs and executed by muthr
- **profile** — a sandbox configuration (manifest + provision script)
- **preset** — llama-server INI configuration (managed by `muthr engine start`)
