<div align="center">
  <img src="https://raw.githubusercontent.com/tappunk/.github/refs/heads/main/assets/muthr-specs.webp" alt="muthr-specs" width="280"/>

# muthr-specs

Source-of-truth configuration and provisioning files for [muthr](https://github.com/tappunk/muthr).

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![X Follow](https://img.shields.io/twitter/follow/tappunk?style=social)](https://x.com/tappunk)

[Structure](#structure) · [Custom Specs](#custom-specs-repo) · [Full Docs](https://tappunk.com/muthr/)
</div>

---

## What's in this repo

- **Container manifests** — per-profile container definitions under `sandbox.d/container/manifests/`
- **Provision scripts** — setup automation under `sandbox.d/container/provision.d/`
- **Model presets** — engine model INI files under `provider.d/`
- **Client templates** — reference configuration under `clients/`

`muthr init` deploys these into `~/.config/muthr/` on your host.

## Structure

```
muthr-specs/
├── sandbox.d/container/
│   ├── manifests/               # Container manifests
│   └── provision.d/             # Provision scripts + shared lib/
├── provider.d/                  # Engine model presets (INI)
├── clients/                     # Reference config templates
└── LICENSE
```

## Custom specs repo

Point `muthr init` at a fork or custom specs repo:

```bash
muthr init --git-url https://github.com/custom/muthr-specs.git
```

## Full documentation

https://tappunk.com/muthr/
