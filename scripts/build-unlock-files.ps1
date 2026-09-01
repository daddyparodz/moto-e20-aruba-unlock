param(
    [string]$OutputDir = "files\unlock"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

& python (Join-Path $PSScriptRoot "build-unlock-files.py") --output-dir $OutputDir
if ($LASTEXITCODE -ne 0) {
    throw "build-unlock-files.py failed with exit $LASTEXITCODE"
}
