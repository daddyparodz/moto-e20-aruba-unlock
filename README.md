# Moto E20 ARUBA Unlock + KernelSU Root

[![Replay package](https://github.com/daddyparodz/moto-e20-aruba-unlock/actions/workflows/verify-release.yml/badge.svg)](https://github.com/daddyparodz/moto-e20-aruba-unlock/actions/workflows/verify-release.yml)

This repository contains the tested, reproducible path for unlocking the bootloader and obtaining persistent KernelSU root on the Motorola Moto E20 `aruba` (`XT2155-3`, Unisoc UMS9230, eMMC) running `RONS31.267-94-14`.

## Verified result

| Check | Hardware result |
|---|---|
| Bootloader | Unlocked |
| Android Verified Boot | `orange` |
| Active slot | `_a` |
| KernelSU | v0.9.5, manager-paired ARMv7 build |
| Root identity | `uid=0(root)`, `u:r:su:s0` |
| Normal reboot | Root and app grants persisted |
| Root Checker Basic | Passed after reboot |

## Start here

1. Read [known failures and traps](docs/KNOWN-FAILURES.md).
2. Follow [the bootloader unlock guide](docs/BOOTLOADER_UNLOCK.md) on a locked phone.
3. After unlock is verified, follow [the KernelSU root guide](docs/ROOT_WITH_KERNELSU.md).

Before touching the phone, verify the package and build the pinned native transport on Linux:

```bash
git clone https://github.com/daddyparodz/moto-e20-aruba-unlock.git
cd moto-e20-aruba-unlock
./scripts/build-linux-tools.sh
python3 scripts/verify-release.py --check-linux-tool build/linux-tools/spd_dump
```

Require `verified_files=23` and `ARUBA_REPLAY_PACKAGE=PASS`.

## What is included

- A reproducible native Linux/libusb transport build, plus the historically tested Windows bundle
- Deterministically rebuilt, hardware-verified unlock payloads
- Stock SPL, U-Boot, and `boot_a` recovery images
- Exact hardware-flashed KernelSU boot image
- Paired 32-bit KernelSU manager and ARMv7 daemon
- Full prewrite/postwrite evidence and SHA-256 manifest

Supporting references:

- [Native Linux host setup](docs/LINUX_HOST.md)
- [Replay package and integrity manifest](release/README.md)
- [Artifacts, backups, and recovery](docs/ARTIFACTS-AND-RECOVERY.md)
- [Verified technical result](docs/STATUS.md)
- [Final manager/root evidence](evidence/kernelsu-manager-pair-v3-20260901/)
- [BootROM and recovery research](docs/BOOTROM-AND-RECOVERY.md)
- [KernelSU source and build provenance](docs/KERNELSU-BUILD.md)

## Supported target and warning

This is an exact-target project for `XT2155-3` / `aruba` / `RONS31.267-94-14` / eMMC / slot A, not a universal Unisoc recipe. Do not substitute another model, firmware, storage layout, loader, address, partition, or hash. Unlocking can erase user data, and an interrupted boot-chain transaction can require BootROM recovery.

The repository documents research on an owner-controlled device. It does not cover carrier, account, FRP, authentication, or anti-theft bypasses.
