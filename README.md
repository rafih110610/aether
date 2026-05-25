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

## Immediate Windows Install (no Release required yet)

```powershell
New-Item -ItemType Directory -Force "$HOME\.local\bin" | Out-Null
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/rafih110610/aether/main/bin/windows-x86_64/aether.exe" -OutFile "$HOME\.local\bin\aether.exe"
& "$HOME\.local\bin\aether.exe" --help
```

This gives Windows users a direct starter binary now.

## Included tools

- `aether` runtime (release assets and starter Linux binary)
- `aether.exe` starter Windows binary
- `air` package CLI
- `aetherpkg` package manager

## Formal Releases

This repo now includes a GitHub Actions release workflow that packages the committed Linux and Windows binaries into versioned release assets matching the installer scripts in `scripts/`.

Create and push a tag like `v0.1.0` to publish a formal release.

## Registry setup

```bash
air registry github rafih110610/aether-air master index.txt
air search color
air install colors
```

See full guide: `docs/AETHER_GUIDE.md`
