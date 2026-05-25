param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LocalIndexDefault = Join-Path $ScriptDir "packages/index.txt"
$IndexFallbackUrl = "https://raw.githubusercontent.com/aether-lang/packages/main/index.txt"

$UserAetherHome = Join-Path $env:USERPROFILE ".local/share/aether"
$UserSitePackages = Join-Path $UserAetherHome "site-packages"
$UserLockFile = Join-Path $UserAetherHome "packages.lock"

$PackagesDir = "aether_packages"
$LockFile = "aether.lock"
$UpdateDependencies = $true

function Write-Usage {
    @"
Usage:
  aetherpkg init
  aetherpkg install [--local|--global] <name> [source]
  aetherpkg uninstall [--local|--global] <name>
  aetherpkg update [--local|--global] [name]
  aetherpkg search <query>
  aetherpkg index
  aetherpkg list [--local|--global]

Examples:
  aetherpkg install colors
  aetherpkg install --global colors
  aetherpkg install colors .\packages\colors.ath
"@
}

function Resolve-ScopeMode([string]$requested) {
    if ($requested -eq "local" -or $requested -eq "global") { return $requested }
    if (Test-Path "aether.toml") { return "local" }
    return "global"
}

function Set-Scope([string]$mode) {
    if ($mode -eq "local") {
        $script:PackagesDir = "aether_packages"
        $script:LockFile = "aether.lock"
        $script:UpdateDependencies = $true
        return
    }

    if ($mode -eq "global") {
        $script:PackagesDir = $UserSitePackages
        $script:LockFile = $UserLockFile
        $script:UpdateDependencies = $false
        return
    }

    throw "Invalid scope mode: $mode"
}

function Ensure-ScopeReady {
    if ($UpdateDependencies -and -not (Test-Path "aether.toml")) {
        throw "Missing aether.toml for local install. Run: aetherpkg init or install with --global"
    }

    New-Item -ItemType Directory -Path $PackagesDir -Force | Out-Null
    if (-not (Test-Path $LockFile)) {
        Set-Content -Path $LockFile -Value "lockfile_version=1"
    }
}

function Get-IndexSource {
    if ($env:AETHERPKG_INDEX) { return $env:AETHERPKG_INDEX }
    if (Test-Path $LocalIndexDefault) { return $LocalIndexDefault }
    return $IndexFallbackUrl
}

function Get-TimeoutSeconds([string]$name, [int]$default) {
    $raw = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($raw)) { return $default }
    $parsed = 0
    if ([int]::TryParse($raw, [ref]$parsed)) { return $parsed }
    return $default
}

function Resolve-IndexToTemp([string]$idx) {
    $tmp = Join-Path $env:TEMP ("aether-index-" + [guid]::NewGuid().ToString() + ".txt")

    if ($idx -match '^https?://') {
        $timeoutSec = Get-TimeoutSeconds -name "AETHERPKG_MAX_TIME" -default 15
        try {
            Invoke-WebRequest -Uri $idx -OutFile $tmp -TimeoutSec $timeoutSec | Out-Null
        } catch {
            if (Test-Path $tmp) { Remove-Item $tmp -Force }
            throw "Failed to fetch package index: $idx"
        }
    } else {
        if (-not (Test-Path $idx)) { throw "Package index file not found: $idx" }
        Copy-Item $idx $tmp -Force
    }

    return $tmp
}

function Resolve-SourceFromIndex([string]$name) {
    $idx = Get-IndexSource
    $idxFile = Resolve-IndexToTemp -idx $idx
    try {
        $line = $null
        foreach ($raw in Get-Content $idxFile) {
            $trim = $raw.Trim()
            if ([string]::IsNullOrWhiteSpace($trim) -or $trim.StartsWith("#")) { continue }
            $parts = $trim.Split('|')
            if ($parts.Length -lt 2) { continue }
            $pkg = $parts[0].Trim()
            if ($pkg -eq $name) {
                $line = $parts
                break
            }
        }

        if (-not $line) {
            throw "Package '$name' not found in index: $idx"
        }

        $src = $line[1].Trim()

        if ($idx -match '^https?://' -and $src -notmatch '^https?://') {
            $base = $idx.Substring(0, $idx.LastIndexOf('/'))
            $src = $src.TrimStart('.', '/')
            return "$base/$src"
        }

        if ($idx -notmatch '^https?://' -and $src -notmatch '^https?://' -and -not [System.IO.Path]::IsPathRooted($src)) {
            $idxDir = Split-Path -Parent (Resolve-Path $idx)
            $src = $src.TrimStart('.', '/', '\\')
            return (Join-Path $idxDir $src)
        }

        return $src
    } finally {
        if (Test-Path $idxFile) { Remove-Item $idxFile -Force }
    }
}

function Ensure-TomlDependenciesSection {
    if (-not (Test-Path "aether.toml")) { return }
    $content = Get-Content "aether.toml"
    if ($content -contains "[dependencies]") { return }
    Add-Content -Path "aether.toml" -Value ""
    Add-Content -Path "aether.toml" -Value "[dependencies]"
}

function Upsert-Dependency([string]$name, [string]$source) {
    if (-not $UpdateDependencies) { return }
    Ensure-TomlDependenciesSection

    $content = Get-Content "aether.toml"
    $out = New-Object System.Collections.Generic.List[string]
    $inDeps = $false
    $written = $false

    foreach ($line in $content) {
        if ($line -match '^\[dependencies\]\s*$') {
            $inDeps = $true
            $out.Add($line)
            continue
        }

        if ($inDeps -and $line -match '^\[') {
            if (-not $written) {
                $out.Add("$name = `"$source`"")
                $written = $true
            }
            $inDeps = $false
        }

        if ($inDeps -and $line -match ('^\s*' + [regex]::Escape($name) + '\s*=')) {
            if (-not $written) {
                $out.Add("$name = `"$source`"")
                $written = $true
            }
            continue
        }

        $out.Add($line)
    }

    if (-not $written) {
        $out.Add("$name = `"$source`"")
    }

    Set-Content -Path "aether.toml" -Value $out
}

function Remove-Dependency([string]$name) {
    if (-not $UpdateDependencies -or -not (Test-Path "aether.toml")) { return }
    $content = Get-Content "aether.toml"
    $out = New-Object System.Collections.Generic.List[string]
    $inDeps = $false

    foreach ($line in $content) {
        if ($line -match '^\[dependencies\]\s*$') {
            $inDeps = $true
            $out.Add($line)
            continue
        }
        if ($inDeps -and $line -match '^\[') {
            $inDeps = $false
        }
        if ($inDeps -and $line -match ('^\s*' + [regex]::Escape($name) + '\s*=')) {
            continue
        }
        $out.Add($line)
    }

    Set-Content -Path "aether.toml" -Value $out
}

function Write-LockEntry([string]$name, [string]$source, [string]$checksum, [string]$filePath) {
    $lines = @()
    if (Test-Path $LockFile) {
        foreach ($line in Get-Content $LockFile) {
            if ($line -match '^lockfile_version=') { $lines += $line; continue }
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line.Split('|')
            if ($parts.Length -ge 1 -and $parts[0] -eq $name) { continue }
            $lines += $line
        }
    }
    if ($lines.Count -eq 0 -or $lines[0] -notmatch '^lockfile_version=') {
        $lines = @('lockfile_version=1') + $lines
    }
    $lines += "$name|$source|$checksum|$filePath"
    Set-Content -Path $LockFile -Value $lines
}

function Remove-LockEntry([string]$name) {
    if (-not (Test-Path $LockFile)) { return }
    $lines = @()
    foreach ($line in Get-Content $LockFile) {
        if ($line -match '^lockfile_version=') { $lines += $line; continue }
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line.Split('|')
        if ($parts.Length -ge 1 -and $parts[0] -eq $name) { continue }
        $lines += $line
    }
    if ($lines.Count -eq 0) { $lines = @('lockfile_version=1') }
    Set-Content -Path $LockFile -Value $lines
}

function Install-FromSource([string]$name, [string]$source) {
    if ($name -notmatch '^[a-zA-Z_][a-zA-Z0-9_]*$') {
        throw "Invalid package name: $name"
    }

    $target = Join-Path $PackagesDir ("$name.ath")
    if ($source -match '^https?://') {
        $timeoutSec = Get-TimeoutSeconds -name "AETHERPKG_MAX_TIME" -default 30
        Invoke-WebRequest -Uri $source -OutFile $target -TimeoutSec $timeoutSec | Out-Null
    } else {
        if (-not (Test-Path $source)) { throw "Source file not found: $source" }
        Copy-Item $source $target -Force
    }

    $checksum = (Get-FileHash -Path $target -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-LockEntry -name $name -source $source -checksum $checksum -filePath $target
    Upsert-Dependency -name $name -source $source

    Write-Host "Installed $name -> $target"
    Write-Host "Source: $source"
    Write-Host "Checksum: $checksum"
}

function Parse-ScopeArgs([string[]]$inputArgs) {
    $mode = "auto"
    $rest = @($inputArgs)
    if ($rest.Count -gt 0 -and ($rest[0] -eq "--local" -or $rest[0] -eq "--global")) {
        $mode = if ($rest[0] -eq "--local") { "local" } else { "global" }
        if ($rest.Count -gt 1) {
            $rest = $rest[1..($rest.Count - 1)]
        } else {
            $rest = @()
        }
    }
    return @{ Mode = $mode; Args = $rest }
}

function Cmd-Init {
    if (Test-Path "aether.toml") {
        Write-Host "aether.toml already exists"
    } else {
        @"
name = "my-aether-project"
version = "0.1.0"
aether = ">=0.1.0"

[dependencies]
"@ | Set-Content -Path "aether.toml"
        Write-Host "Created aether.toml"
    }

    if (Test-Path "aether.lock") {
        Write-Host "aether.lock already exists"
    } else {
        Set-Content -Path "aether.lock" -Value "lockfile_version=1"
        Write-Host "Created aether.lock"
    }

    New-Item -ItemType Directory -Path "aether_packages" -Force | Out-Null
}

function Cmd-Install([string[]]$argsIn) {
    $parsed = Parse-ScopeArgs $argsIn
    $args = @($parsed.Args)
    if ($args.Count -lt 1 -or $args.Count -gt 2) { Write-Usage; exit 2 }

    $mode = Resolve-ScopeMode $parsed.Mode
    Set-Scope $mode
    Ensure-ScopeReady

    $name = $args[0]
    $source = if ($args.Count -eq 2) { $args[1] } else { Resolve-SourceFromIndex $name }
    Install-FromSource -name $name -source $source
}

function Cmd-Uninstall([string[]]$argsIn) {
    $parsed = Parse-ScopeArgs $argsIn
    $args = @($parsed.Args)
    if ($args.Count -ne 1) { Write-Usage; exit 2 }

    $mode = Resolve-ScopeMode $parsed.Mode
    Set-Scope $mode
    Ensure-ScopeReady

    $name = $args[0]
    $target = Join-Path $PackagesDir ("$name.ath")
    if (Test-Path $target) { Remove-Item $target -Force }
    Remove-LockEntry -name $name
    Remove-Dependency -name $name
    Write-Host "Uninstalled $name"
}

function Cmd-Update([string[]]$argsIn) {
    $parsed = Parse-ScopeArgs $argsIn
    $args = @($parsed.Args)
    if ($args.Count -gt 1) { Write-Usage; exit 2 }

    $mode = Resolve-ScopeMode $parsed.Mode
    Set-Scope $mode
    Ensure-ScopeReady

    if ($args.Count -eq 1) {
        $name = $args[0]
        $line = Get-Content $LockFile | Where-Object { $_ -notmatch '^lockfile_version=' -and $_.Split('|')[0] -eq $name } | Select-Object -First 1
        if (-not $line) { throw "Package '$name' is not installed" }
        $source = $line.Split('|')[1]
        Install-FromSource -name $name -source $source
        return
    }

    $entries = Get-Content $LockFile | Where-Object { $_ -notmatch '^lockfile_version=' -and -not [string]::IsNullOrWhiteSpace($_) }
    if (-not $entries -or $entries.Count -eq 0) {
        Write-Host "No installed packages to update"
        return
    }

    foreach ($entry in $entries) {
        $parts = $entry.Split('|')
        if ($parts.Length -lt 2) { continue }
        Install-FromSource -name $parts[0] -source $parts[1]
    }
}

function Cmd-Search([string[]]$args) {
    if ($args.Count -ne 1) { Write-Usage; exit 2 }
    $query = $args[0].ToLowerInvariant()
    $idx = Get-IndexSource
    $idxFile = Resolve-IndexToTemp -idx $idx
    try {
        $printed = $false
        foreach ($raw in Get-Content $idxFile) {
            $trim = $raw.Trim()
            if ([string]::IsNullOrWhiteSpace($trim) -or $trim.StartsWith("#")) { continue }
            $parts = $trim.Split('|')
            if ($parts.Length -lt 2) { continue }
            $name = $parts[0].Trim()
            $src = $parts[1].Trim()
            $desc = if ($parts.Length -ge 3) { $parts[2].Trim() } else { "" }
            $line = ($name + " " + $src + " " + $desc).ToLowerInvariant()
            if ($line.Contains($query)) {
                Write-Host ($name.PadRight(18) + " " + $src.PadRight(45) + " " + $desc)
                $printed = $true
            }
        }
        if (-not $printed) {
            Write-Host "No packages found for query: $($args[0])"
        }
    } finally {
        if (Test-Path $idxFile) { Remove-Item $idxFile -Force }
    }
}

function Cmd-Index {
    Write-Host "Aether package index: $(Get-IndexSource)"
}

function Cmd-List([string[]]$argsIn) {
    $parsed = Parse-ScopeArgs $argsIn
    $args = @($parsed.Args)
    if ($args.Count -ne 0) { Write-Usage; exit 2 }

    $mode = Resolve-ScopeMode $parsed.Mode
    Set-Scope $mode

    if (-not (Test-Path $LockFile)) {
        Write-Host "No lockfile found"
        return
    }

    foreach ($line in Get-Content $LockFile) {
        if ($line -match '^lockfile_version=' -or [string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line.Split('|')
        if ($parts.Length -ge 4) {
            Write-Host ($parts[0].PadRight(20) + " " + $parts[3].PadRight(50) + " " + $parts[2])
        }
    }
}

if ($args.Count -lt 1) {
    Write-Usage
    exit 2
}

$cmd = $args[0]
$rest = if ($args.Count -gt 1) { @($args[1..($args.Count - 1)]) } else { @() }

switch ($cmd) {
    "init" { Cmd-Init }
    "install" { Cmd-Install $rest }
    "add" { Cmd-Install $rest }
    "uninstall" { Cmd-Uninstall $rest }
    "remove" { Cmd-Uninstall $rest }
    "rm" { Cmd-Uninstall $rest }
    "update" { Cmd-Update $rest }
    "upgrade" { Cmd-Update $rest }
    "search" { Cmd-Search $rest }
    "find" { Cmd-Search $rest }
    "index" { Cmd-Index }
    "list" { Cmd-List $rest }
    default {
        Write-Usage
        exit 2
    }
}
