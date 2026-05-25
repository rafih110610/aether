# Aether Guide

This guide explains what Aether is, how to install and run it, and how to use package registry workflows with AIR.

## What Is Aether?

Aether is an indentation-based programming language using `.ath` files. It includes:

- Native runtime binary (`aether`)
- Script debugger
- Lint/check/format/test commands
- Package workflows via `aetherpkg` and `air`

## Install Aether Runtime

### Linux and macOS

- `bash scripts/install.sh`
- Optional override: `bash scripts/install.sh owner/repo`

### Windows PowerShell

- `powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1`
- Optional override: `powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Repo owner/repo`

Windows installer also installs:

- `air.ps1` + `air.cmd`
- `aetherpkg.ps1` + `aetherpkg.cmd`

So you can run `air` and `aetherpkg` directly from PowerShell or Command Prompt.

## Run Aether Scripts

- `aether examples/demo.ath`
- `aether run examples/demo.ath`
- `aether repl`
- `aether test tests`
- `aether check examples`
- `aether lint examples/demo.ath`
- `aether fmt examples/demo.ath`

## Create a New Project

- `aether new my-app`
- `cd my-app`
- `aether main.ath`
- `aether test tests`

## Package Tooling Overview

- `aetherpkg`: lower-level package manager
- `air`: user-friendly package command for install/search/publish and registry setup

Install globally in user scope (pip-like):

- `air install --global colors`

Install in a local project scope:

- `air init`
- `air install --local colors`

## Configure Registry

Set a GitHub registry index:

- `air registry github <owner/repo> <branch> <index-path>`

Show current registry:

- `air registry show`

Reset registry configuration:

- `air registry reset`

## Search and Install Packages

- `air search color`
- `air install colors`
- `air list`
- `air uninstall colors`

Windows PowerShell example:

- `air install colors`
- `air list`

## Publish a Package

Publish a package to configured registry:

- `air publish colors ./packages/colors.ath "Basic color constants"`

Windows PowerShell equivalent:

- `air publish colors .\packages\colors.ath "Basic color constants"`

Dry run publish (prepare commit, push manually):

- `air publish colors ./packages/colors.ath "Basic color constants" --no-push`

## Registry Index Format

A registry index is a text file with one package per line:

- `name|source|description`

Example:

- `colors|./colors.ath|Basic color constants`

## Recommended Public Setup

1. Keep one canonical branch for registry (for example `main`).
2. Keep one canonical index path (for example `index.txt`).
3. Use PRs for package updates.
4. Enable CI validation for index quality and package syntax.

## Troubleshooting

If package search returns nothing:

1. Run `air registry show` and confirm branch/path.
2. Open raw index URL and verify package entry exists.
3. Confirm source paths in index point to real files.

If network is slow:

- `export AETHERPKG_CONNECT_TIMEOUT=5`
- `export AETHERPKG_MAX_TIME=20`

If `air` command is not found:

1. Ensure executable is in `~/.local/bin`.
2. Add PATH entry in shell profile:
   - `export PATH="$HOME/.local/bin:$PATH"`
