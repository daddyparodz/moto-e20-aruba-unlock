# Known failures and traps

These are observed failures from the tested Moto E20 ARUBA work. Preserve them; they prevent repeating expensive or risky experiments.

This project supports only `XT2155-3` / `aruba` / `RONS31.267-94-14` / eMMC / slot A. A similar model name, newer firmware, UFS storage, or another active slot is not evidence of compatibility; stop instead of adapting addresses, loaders, partitions, or images by guesswork.

## BootROM and transport

- Run `spd_dump.exe` from the directory containing `custom_exec_no_verify_65015f08.bin`. Running it from the repository root produced `custom_exec_no_verify_65015f08.bin does not exist`, followed by FDL1 baud failures.
- Windows may briefly show an unrecognized USB device. The tested BootROM interface is Unisoc `1782:4d00` / `SPRD U2S Diag`; fix the driver binding before retrying the payload.
- Arm the listener before asking for BootROM entry. The enumeration window is short, so a manual start after connection is unreliable.
- `FDL2: incompatible partition` appeared during the successful loader transition and was not fatal when the partition table subsequently loaded and the `FDL2 >` prompt appeared.
- After `poweroff`, stop the outer reconnect loop. Otherwise it can reconnect to a stale COM port while the phone is leaving download mode.

## Bootloader unlock

- Do not use the v1, v2, old FDL1-RAM, or older cboot routes. The maintained and hardware-verified procedure is [BOOTLOADER_UNLOCK.md](BOOTLOADER_UNLOCK.md).
- Do not repeat the one-shot `spl-unlock` stage merely because `spd_dump` returns nonzero while USB disappears. That transition occurred during the successful run and is intentionally non-idempotent.
- Never attempt a normal boot while both SPL copies are erased. Restore exact stock U-Boot, `splloader`, and `splloader_bak` first.
- Do not rerun the unlock transaction when Android already reports `ro.boot.flash.locked=0` and `ro.boot.vbmeta.device_state=unlocked`.

## Root images

- Magisk F4, SHA256 `F4B48B5BAD9FFFB79897E09946172EB0273850B0F81CF8CC91591722DB41A0EE`, bootlooped on hardware. Do not flash it again.
- The first KernelSU user build booted but did not provide root because no compatible userspace daemon was present.
- The first debug `/system/bin/sh` fallback also booted but did not provide root. Its debug shell profile had implicit version zero, which `profile_valid()` rejects.
- V2 fixed that specific bug with `.version = KSU_APP_PROFILE_VER`; its full `boot_a` readback and reboot-persistence evidence are retained under `evidence/persistent-root-20260901/`.
- Always read and hash all 64 MiB of `boot_a` before and after a write. A successful write command alone is not acceptance evidence.

## KernelSU manager

- The official `KernelSU_v0.9.5_11872-release.apk` is correctly signed for upstream v0.9.5 but contains no `armeabi-v7a` JNI library. ARUBA Android is `zygote32` with `ro.product.cpu.abilist=armeabi-v7a,armeabi`; installation fails with `INSTALL_FAILED_NO_MATCHING_ABIS`.
- Do not infer userspace ABI from the ARM64 kernel. This phone reports `armv8l` for the kernel while Android itself is 32-bit only.
- Rebuilding the manager changes its signing certificate. KernelSU must be built with `KSU_EXPECTED_SIZE` and `KSU_EXPECTED_HASH` matching the rebuilt APK certificate, or the throne tracker will not recognize the app as manager.
- An ARMv7 manager without `libksud.so` can change an app profile only in live kernel memory. If `/data/adb/ksu` and `/data/adb/ksud` are absent, `.allowlist` cannot be saved; the grant disappears after reboot even though kernel root remains. Use the retained `with-ksud` APK and install the retained ARMv7 daemon before granting apps.
- Do not commit a private APK signing key. The retained paired APK and public certificate are sufficient for installing the proven build; rebuilding an update requires deliberately creating a new pairing.

## Verification

- `orange` verified boot is expected after unlock. It does not mean the unlock or root failed.
- Root is accepted only when `id` reports UID 0 and `id -Z` reports `u:r:su:s0`, followed by the same result after an ordinary Android reboot.
- Keep negative evidence. A failed candidate is marked historical/known-bad rather than silently overwritten.
