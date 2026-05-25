param(
    [Parameter(Mandatory = $false)]
    [string]$Repo = "rafih110610/aether"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -eq "AMD64") {
    $target = "x86_64-pc-windows-msvc"
} else {
    throw "Unsupported architecture: $arch"
}

$api = "https://api.github.com/repos/$Repo/releases/latest"
$release = Invoke-RestMethod -Uri $api -TimeoutSec 60
$asset = $release.assets | Where-Object { $_.name -like "*-$target.zip" } | Select-Object -First 1

if (-not $asset) {
    throw "Could not find release asset for target $target"
}

$tmp = Join-Path $env:TEMP "aether-install-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $tmp | Out-Null

$zipPath = Join-Path $tmp "aether.zip"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -TimeoutSec 120
Expand-Archive -Path $zipPath -DestinationPath $tmp -Force

$exe = Get-ChildItem -Path $tmp -Recurse -Filter "aether.exe" | Select-Object -First 1
if (-not $exe) {
    throw "Extracted archive does not contain aether.exe"
}

$installDir = Join-Path $env:USERPROFILE ".local\bin"
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Copy-Item $exe.FullName (Join-Path $installDir "aether.exe") -Force

$airPs1 = Get-ChildItem -Path $tmp -Recurse -Filter "air.ps1" | Select-Object -First 1
$aetherpkgPs1 = Get-ChildItem -Path $tmp -Recurse -Filter "aetherpkg.ps1" | Select-Object -First 1

if ($airPs1) {
    Copy-Item $airPs1.FullName (Join-Path $installDir "air.ps1") -Force
    @"
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0air.ps1" %*
"@ | Set-Content -Path (Join-Path $installDir "air.cmd")
}

if ($aetherpkgPs1) {
    Copy-Item $aetherpkgPs1.FullName (Join-Path $installDir "aetherpkg.ps1") -Force
    @"
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0aetherpkg.ps1" %*
"@ | Set-Content -Path (Join-Path $installDir "aetherpkg.cmd")
}

Write-Host "Installed Aether to $installDir\aether.exe"
if ($airPs1) {
    Write-Host "Installed AIR to $installDir\air.ps1 (+ air.cmd shim)"
}
if ($aetherpkgPs1) {
    Write-Host "Installed aetherpkg to $installDir\aetherpkg.ps1 (+ aetherpkg.cmd shim)"
}
Write-Host "Add $installDir to PATH to run 'aether' globally."
