param(
    [switch]$Execute,
    [string]$WorkDir = "C:\aruba-bootrom-cycle",
    [int]$WaitSeconds = 180
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$tools = Join-Path $repoRoot "files\bootrom\windows-tools"
$loaders = Join-Path $repoRoot "files\unlock"

function Assert-File([string]$Path, [long]$Size, [string]$Sha256) {
    if (-not (Test-Path $Path)) { throw "Missing file: $Path" }
    if ((Get-Item $Path).Length -ne $Size) { throw "Size mismatch: $Path" }
    if ((Get-FileHash $Path -Algorithm SHA256).Hash -ne $Sha256) { throw "SHA-256 mismatch: $Path" }
}

Assert-File (Join-Path $tools "spd_dump.exe") 80896 "2E4C117EB22FF800448FF827740AC280FAAEE19B579F8D85577C8F15C2065D7C"
Assert-File (Join-Path $loaders "fdl1.bin") 60664 "98A308E4C755219D592288EB668117B938C3435783DD5E0F75E450CDCE5A3076"
Assert-File (Join-Path $loaders "fdl2.bin") 1159000 "5BCAE75A8E3A940B294F46DDE2CD8FC5817A89A0544C917437A500A9188F03B3"

if (-not $Execute) {
    Write-Host "DRY RUN: files verified; no phone command was sent."
    Write-Host "Use -Execute to arm spd_dump, request 'adb reboot autodloader', load FDL1/FDL2, then issue reset."
    exit 0
}

$device = (& adb get-state 2>$null | Out-String).Trim()
if ($device -ne "device") { throw "Exactly one authorized ADB device must be online." }
$product = (& adb shell getprop ro.product.device | Out-String).Trim()
$build = (& adb shell getprop ro.build.display.id | Out-String).Trim()
$rootId = (& adb shell "su -c id" | Out-String).Trim()
if ($product -ne "aruba" -or $build -ne "RONS31.267-94-14") { throw "Target mismatch: product=$product build=$build" }
if ($rootId -notmatch "uid=0\(root\)") { throw "Persistent root is not available." }

New-Item -ItemType Directory -Force $WorkDir | Out-Null
Copy-Item (Join-Path $tools "*") $WorkDir -Force
Copy-Item (Join-Path $loaders "fdl1.bin") $WorkDir -Force
Copy-Item (Join-Path $loaders "fdl2.bin") $WorkDir -Force

$stdout = Join-Path $WorkDir "bootrom-cycle.log"
$stderr = Join-Path $WorkDir "bootrom-cycle-error.log"
$arguments = @(
    "--wait", "$WaitSeconds",
    "exec_addr", "0x65015f08",
    "fdl", "fdl1.bin", "0x65000800",
    "fdl", "fdl2.bin", "0x9efffe00",
    "exec",
    "reset"
)

$process = Start-Process -FilePath (Join-Path $WorkDir "spd_dump.exe") `
    -ArgumentList $arguments `
    -WorkingDirectory $WorkDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -PassThru

Start-Sleep -Milliseconds 500
& adb reboot autodloader
if ($LASTEXITCODE -ne 0) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw "ADB rejected the autodloader reboot request."
}

if (-not $process.WaitForExit(($WaitSeconds + 30) * 1000)) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw "BootROM/FDL transport timed out. See $stdout and $stderr"
}
if ($process.ExitCode -ne 0) { throw "spd_dump exited with code $($process.ExitCode). See $stdout and $stderr" }

$deadline = (Get-Date).AddSeconds($WaitSeconds)
do {
    Start-Sleep -Seconds 2
    $state = (& adb get-state 2>$null | Out-String).Trim()
} until ($state -eq "device" -or (Get-Date) -ge $deadline)

if ($state -ne "device") { throw "FDL reset completed, but Android ADB did not return before timeout." }
Write-Host "BOOTROM_COMMAND_CYCLE=PASS"
Write-Host "The phone entered the Unisoc loader path and returned to Android without a partition write."
