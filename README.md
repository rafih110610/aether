# Aether Public Distribution

This repository is the public distribution channel for Aether runtime binaries and user tooling.

It intentionally contains only release/runtime artifacts and user-facing tools.

## Quick Start

### Linux/macOS

```bash
bash scripts/install.sh
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```


## Immediate Linux Install (no Release required yet)

```bash
curl -fsSL https://raw.githubusercontent.com/rafih110610/aether/main/bin/linux-x86_64/aether -o ~/.local/bin/aether
chmod +x ~/.local/bin/aether
aether --help
```

This lets friends start right away while you prepare formal GitHub Release artifacts.

## Included tools

- `aether` runtime (release assets and starter Linux binary)
- `air` package CLI
- `aetherpkg` package manager

## Registry setup

```bash
air registry github rafih110610/aether-air master index.txt
air search color
air install colors
```

See full guide: `docs/AETHER_GUIDE.md`
