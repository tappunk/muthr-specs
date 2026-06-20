[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![X Follow](https://img.shields.io/twitter/follow/tappunk?style=social)](https://x.com/tappunk)

# muthr-specs

Lima templates, model presets, and provisioning scripts for [muthr](https://github.com/tappunk/muthr).

> [!NOTE]
> These configs deploy to `~/.config/muthr/` via `muthr init`. You need muthr installed before using these profiles.

## Usage

Profiles are deployed by `muthr init` and `muthr deploy`:

```bash
# Clone configs into ~/.config/muthr/
muthr init

# List available profiles
muthr profiles list

# Deploy a profile (creates Lima VM from template)
muthr deploy dev-sandbox

# Start llama-server with a preset
muthr serve --preset bw600g-qwen3.6-35b-a3b

# Full workflow: server + VM
muthr up
```

## Structure

```
muthr-specs/
├── catalog.json              # Profile registry (name, description, tags)
├── clients/                  # Client configuration templates
│   └── opencode-config.json  # OpenCode config template (injected into VMs)
├── manifests/                # Lima YAML templates
│   ├── base/                 # Reference templates for contributors
│   │   └── debian-vz.yaml    # Self-contained Debian 13 + vz (starting point for new profiles)
│   ├── dev-sandbox.yaml      # Development VM template
│   ├── hermes-agent.yaml     # Hermes Agent environment template
│   └── mcp-services.yaml     # MCP services VM template
├── provider.d/               # Lima providers with presets and scripts
│   ├── llama-cpp/            # llama.cpp presets (*.ini → llama-server flags)
│   │   ├── bw600g-qwen3.6-35b-a3b.ini
│   │   └── bw150g-qwen3.5-9b.ini
│   └── provision.d/          # Lima provision scripts (used via file: in YAML)
│       ├── lib/provision-lib.sh
│       ├── mcp-services.sh
│       └── opencode.sh
└── LICENSE
```

## Lima Templates

All profiles are self-contained Lima YAML files — no base templates or `base:` references. Each template defines the complete VM configuration (images, cpus, memory, mounts, provision scripts). This matches Lima's own template organization and avoids path resolution issues.

To create a new profile, copy `manifests/base/debian-vz.yaml` as a starting point and customize:

```yaml
# my-profile.yaml
minimumLimaVersion: 2.0.0

vmType: "vz"
mountType: "virtiofs"

images:
  - location: "https://cloud.debian.org/images/cloud/trixie/20260525-2489/debian-13-genericcloud-arm64-20260525-2489.qcow2"
    arch: "aarch64"
    digest: "sha512:b4f9240559da2c044953418d0632cee4d45e3d447a0ec6a9129ef7946e39ec4135ec9e085c176f8dc77af6536d7279c03487e9aa61fd6c628fb493886e23aef5"
  - location: "https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-genericcloud-arm64-daily.qcow2"
    arch: "aarch64"

cpus: 2 # override defaults
memory: "4GiB" # override defaults
disk: "50GiB" # override defaults

mounts: # add custom mounts
  - location: "~/src"
    mountPoint: "/workspace"
    writable: true

containerd:
  user: true

ssh:
  forwardAgent: false

hostResolver:
  enabled: true
  ipv6: false

provision: # inline provision scripts (Lima supports both)
  - mode: system
    script: |
      #!/bin/bash
      apt-get install -y vim
```

## Presets

Preset files define llama-server configuration as INI files. Each preset maps to model-specific settings (GPU layers, context size, sampling parameters). They are loaded by `muthr serve --preset <name>`.

## Configuration

Configs deploy to `~/.config/muthr/` after running `muthr init`:

- `provider.d/*/presets/*.ini` — model profiles with GPU layers, context size, sampling params
- `manifests/*.yaml` — VM templates for dev sandboxes, MCP services, and agent environments
- `provision.d/*.sh` — boot scripts injected into VMs at launch time

## Contributing

New profiles, presets, and provision scripts are welcome via PRs.

### Adding a Lima Template

1. Copy `manifests/base/debian-vz.yaml` as your starting point
2. Customize cpus, memory, disk, mounts for your use case
3. Add inline `provision:` scripts
4. Add an entry to `catalog.json`
5. Submit a PR

### Adding a Preset

1. Create a new `.ini` file in `provider.d/<provider>/` (e.g. `provider.d/llama-cpp/`)
2. Use the existing presets as format reference
3. Submit a PR

### Provision Scripts

Scripts in `provision.d/` are shared utility scripts. Lima templates can reference them via `file:` in the provision section:

```yaml
provision:
  - mode: user
    file: provision.d/opencode.sh
```

Lima resolves relative paths from the YAML file's directory.
