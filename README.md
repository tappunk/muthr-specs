![muthr-specs](https://raw.githubusercontent.com/tappunk/.github/refs/heads/main/assets/muthr-specs.webp)

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![X Follow](https://img.shields.io/twitter/follow/tappunk?style=social)](https://x.com/tappunk)

# muthr-specs
> \[!NOTE]
> Experimental not for production use

Configuration files for [muthr](https://github.com/tappunk/muthr).

[Structure](#structure) • [Profiles](#profiles) • [Environment Variables](#environment-variables) • [Adding a New Profile](#adding-a-new-profile)

## Installation

```bash
muthr init
```

Use a custom specs repo:

```bash
muthr init --git-url https://github.com/custom/muthr-specs.git
```

See [muthr](https://github.com/tappunk/muthr) for architecture and usage.

## Structure

```
muthr-specs/
├── sandbox.d/container/
│   ├── manifests/               # Container manifests
│   └── provision.d/             # Provision scripts + shared lib/
├── clients/                     # Reference config templates
└── LICENSE
```

See [muthr](https://github.com/tappunk/muthr) for architecture details.

## Profiles

Profile assets live in `sandbox.d/container/`. See [muthr](https://github.com/tappunk/muthr) for documentation.

### base

Minimal Debian 13 container.

### opencode

Installs opencode CLI and MCP servers.

### muthr-services

Persistent services container for SearXNG and MCP bridge.

## Environment Variables

See [muthr](https://github.com/tappunk/muthr) for environment variable documentation.

## Script conventions

- Use `set -Eeuo pipefail`
- Set `DEBIAN_FRONTEND=noninteractive`
- Keep shared helpers in `sandbox.d/container/provision.d/lib/`

## Adding a New Profile

1. Create `sandbox.d/container/provision.d/<profile>.sh`
2. Optionally add `sandbox.d/container/manifests/<profile>.yaml`
3. Optionally add a reference template under `clients/`

See [muthr](https://github.com/tappunk/muthr) for usage and architecture.
