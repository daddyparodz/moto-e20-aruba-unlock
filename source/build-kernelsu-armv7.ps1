param(
    [Parameter(Mandatory = $true)]
    [string]$AndroidNdk,
    [string]$JavaHome = $env:JAVA_HOME
)

$ErrorActionPreference = "Stop"
$sourceRoot = Join-Path $PSScriptRoot "kernelsu-v0.9.5"
$managerRoot = Join-Path $sourceRoot "manager"
$ksudRoot = Join-Path $sourceRoot "userspace\ksud"
$clang = Join-Path $AndroidNdk "toolchains\llvm\prebuilt\windows-x86_64\bin\armv7a-linux-androideabi26-clang.cmd"

if (-not (Test-Path $clang)) { throw "Android NDK ARMv7 API 26 clang not found: $clang" }
if ([string]::IsNullOrWhiteSpace($JavaHome) -or -not (Test-Path $JavaHome)) { throw "Set JAVA_HOME or pass -JavaHome." }

$env:JAVA_HOME = (Resolve-Path $JavaHome).Path
$env:CC_armv7_linux_androideabi = $clang
$env:CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER = $clang

rustup target add armv7-linux-androideabi
if ($LASTEXITCODE -ne 0) { throw "rustup target installation failed" }

cargo build --manifest-path (Join-Path $ksudRoot "Cargo.toml") --release --target armv7-linux-androideabi
if ($LASTEXITCODE -ne 0) { throw "ARMv7 ksud build failed" }

$ksud = Join-Path $ksudRoot "target\armv7-linux-androideabi\release\ksud"
$jniDir = Join-Path $managerRoot "app\src\main\jniLibs\armeabi-v7a"
New-Item -ItemType Directory -Force $jniDir | Out-Null
Copy-Item $ksud (Join-Path $jniDir "libksud.so") -Force

Push-Location $managerRoot
try {
    & .\gradlew.bat :app:clean :app:assembleDebug
    if ($LASTEXITCODE -ne 0) { throw "KernelSU manager build failed" }
} finally {
    Pop-Location
}

Write-Host "ARMv7 ksud: $ksud"
Write-Host "Manager APK: $managerRoot\app\build\outputs\apk\debug\app-debug.apk"
Write-Warning "This APK uses your local debug certificate and is not paired with the repository's flashed kernel."
