# Root the Moto E20 ARUBA with persistent KernelSU

This is the single maintained root procedure proven on one Motorola Moto E20 `XT2155-3`, codename `aruba`, Unisoc `ums9230`, eMMC, Android 11 build `RONS31.267-94-14`. It assumes the bootloader is already unlocked. Read this guide and [known failures](KNOWN-FAILURES.md) completely before writing anything.

## 0. Clone and verify the complete package

The preferred host is native x86-64 Linux with Git, Python 3, libusb development files, a C compiler, and Android Platform Tools (`adb`). Follow [the Linux host guide](LINUX_HOST.md) for transport compilation and udev access. The original PAC is not required for replay. The Windows bundle remains available as historical evidence and a tested fallback.

```bash
git clone https://github.com/daddyparodz/moto-e20-aruba-unlock.git
cd moto-e20-aruba-unlock
./scripts/build-linux-tools.sh
python3 scripts/verify-release.py --check-linux-tool build/linux-tools/spd_dump
```

Require `LINUX_TRANSPORT_BUILD=PASS`, `verified_files=23`, and `ARUBA_REPLAY_PACKAGE=PASS`. Stop on any missing file, size mismatch, or hash mismatch. Install the supplied udev rule as described in the Linux guide before connecting BootROM USB `1782:4d00`.

## 1. Verify the prerequisite and exact target

Back up anything important elsewhere. With Android booted and USB debugging authorized:

```powershell
adb shell getprop ro.product.device
adb shell getprop ro.build.display.id
adb shell getprop ro.boot.slot_suffix
adb shell getprop ro.boot.flash.locked
adb shell getprop ro.boot.vbmeta.device_state
```

Require, in order, `aruba`, `RONS31.267-94-14`, `_a`, `0`, and `unlocked`. Stop on any mismatch. If the last two values do not prove unlock, complete [the bootloader-unlock guide](BOOTLOADER_UNLOCK.md) first; do not continue into this root procedure.

## 2. Prepare BootROM transport

Copy the retained transport bundle to a writable work directory because `spd_dump` creates readbacks and partition-list files beside the executable:

```powershell
$repo = (Resolve-Path .).Path
$tools = 'C:\aruba-e20-tools'
New-Item -ItemType Directory -Force $tools | Out-Null
Copy-Item "$repo\files\bootrom\windows-tools\*" $tools -Force

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\unlock-bootloader.ps1 `
  -StaticPrecheckOnly `
  -WorkDir $tools `
  -FdlDir "$repo\files\unlock"
```

Require `V3 STATIC PRECHECK RESULT: PASS`. The tested build reports source marker `fa0becf5e3f026b3b99103c65de6eb9a8348b27c`. Keep `Channel9.dll`, `Channel.ini`, `spd_dump.exe`, and the helper together and run from `$tools`.

Arm the connection before entering BootROM:

```powershell
Push-Location $tools
while ($true) {
  .\spd_dump.exe --wait 3600 `
    exec_addr 0x65015f08 `
    fdl "$repo\files\unlock\fdl1.bin" 0x65000800 `
    fdl "$repo\files\unlock\fdl2.bin" 0x9efffe00 `
    exec
  Start-Sleep -Milliseconds 150
}
```

Use `Ctrl+C` and `Pop-Location` after the operation. `FDL2: incompatible partition` was nonfatal on the tested phone when the correct partition table followed; a missing/wrong table, storage type, slot, or size is still a hard stop.

Power off, unplug USB, hold Volume Up + Volume Down, and reconnect USB. Expected USB identity: `1782:4d00` / `SPRD U2S Diag`. Require eMMC, slot A, and a 64 MiB `boot_a` in the partition list.

## 3. Select the manager-paired boot image

The final image is under:

```text
files/root/
```

Use `boot.img`. Require size `67108864` and SHA-256 `F9A3DE1A4C377EA2871A03E6437F75F38BF4A0532A36A2418CA1BAE78DE78D70`. If only `boot.img.xz` exists, decompress it with `xz -dk` and verify against `BUILD-RESULT.txt` beside it.

## 4. Back up, write, and read back `boot_a`

At `FDL2 >`, confirm `Device is using slot a`, then read all of `boot_a`:

```text
r boot_a
```

`spd_dump` writes `boot_a.bin` in its working directory. While the first terminal remains at `FDL2 >`, use a second PowerShell window to require size `67108864`, hash the file, and preserve it before writing:

```powershell
Get-Item "$tools\boot_a.bin" | Select-Object FullName,Length
Get-FileHash "$tools\boot_a.bin" -Algorithm SHA256
Copy-Item "$tools\boot_a.bin" "$tools\boot_a-prewrite-backup.bin"
```

Write only `boot_a`, then read it all back:

```text
skip_confirm 1
w boot_a C:\absolute\path\to\files\root\boot.img
r boot_a
```

After the postwrite `r boot_a`, use the second PowerShell window to immediately hash the newly written `boot_a.bin`:

```powershell
Get-Item "$tools\boot_a.bin" | Select-Object FullName,Length
Get-FileHash "$tools\boot_a.bin" -Algorithm SHA256
```

Require write/read sizes of `0x4000000`, readback size `67108864`, and SHA-256 `F9A3DE1A4C377EA2871A03E6437F75F38BF4A0532A36A2418CA1BAE78DE78D70`. On failure, remain in FDL and restore the saved image, then read and hash the full partition again:

```text
w boot_a C:\aruba-e20-tools\boot_a-prewrite-backup.bin
r boot_a
```

On success, enter `poweroff`, stop the listener, and boot normally.

## 5. Install the paired manager

ARUBA Android is 32-bit-only despite its ARM64 kernel. The official v0.9.5 APK is retained for audit but cannot install here.

```powershell
adb install -r .\files\root\manager.apk
adb shell dumpsys package me.weishu.kernelsu | findstr /C:"userId=" /C:"primaryCpuAbi=" /C:"versionCode=" /C:"versionName="
```

Require APK SHA-256 `57FB4AAEFF55D4B8A0428738399CCF3D27153FC7F3BC50565B7EDFB291B90AF2`, `primaryCpuAbi=armeabi-v7a`, `versionCode=11872`, and `versionName=v0.9.5`. Exact APK/signer provenance is in `files/root/MANAGER-BUILD.txt`; modified source is under `source/kernelsu-v0.9.5/`.

Install the matching ARMv7 `ksud` so app grants are saved and restored after reboot:

```powershell
adb push .\files\root\ksud /data/local/tmp/ksud-armv7
adb shell "su -c 'mkdir -p /data/adb/ksu; cp /data/local/tmp/ksud-armv7 /data/adb/ksud; chown 0:0 /data/adb/ksud; chmod 0755 /data/adb/ksud; /data/adb/ksud --version'"
```

Require daemon SHA-256 `504DBBE6439F82F5624A891DF31885FACB74FAA1AD89FCC302968842403A8AD5` and output `ksud 0.9.5`.

## 6. Verify root and authorize apps

```powershell
adb shell "/system/bin/su -c 'id; id -Z'"
```

Require UID 0 and `u:r:su:s0`. Open KernelSU, choose Superuser, find the desired app, and enable it. Then launch the app and let it request `su`.

For Root Checker Basic, the package is `com.joeykrim.rootcheck`. Accept the result only after KernelSU lists/allows it and Root Checker reports root access.

## 7. Prove persistence

```powershell
adb reboot
adb wait-for-device
adb shell getprop sys.boot_completed
adb shell "/system/bin/su -c 'id; id -Z'"
```

Wait for `sys.boot_completed=1`, require UID 0 and `u:r:su:s0` again, and confirm KernelSU still lists the app as root-enabled. The tested Root Checker result after reboot is `Congratulations! Root access is properly installed on this device.`

## 8. Recovery and failed routes

- [ARTIFACTS-AND-RECOVERY.md](ARTIFACTS-AND-RECOVERY.md) maps stock files, backups, builds, and recovery material.
- [KNOWN-FAILURES.md](KNOWN-FAILURES.md) records prohibited unlock routes, bootloop images, KernelSU profile/ABI failures, BootROM traps, and retry boundaries.

Never discard a unique prewrite image or silently rewrite a negative result.

## 9. Exact replay versus source rebuild

The operational path above uses the exact hardware-tested files bound by `release/ARUBA-REPLAY-MANIFEST.json`. Source rebuilds are useful for audit, but legacy ThinLTO output can change with absolute build paths. Never flash a fresh rebuild solely because its filename matches.

The retained output directory contains construction commands and complete boot-v2/AVB verification. Pinned kernel, manager, and daemon source provenance is documented in [KERNELSU-BUILD.md](KERNELSU-BUILD.md).
