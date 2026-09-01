# Verified project status

Research on the tested Motorola Moto E20 ARUBA target is complete.

## Target

```text
model       XT2155-3
codename    aruba
platform    Unisoc UMS9230
storage     eMMC
firmware    RONS31.267-94-14
slot        _a
```

## Bootloader unlock

The guarded V3 transaction completed on hardware, restored stock U-Boot and both stock SPL copies, and booted Android normally. Android reported:

```text
ro.boot.flash.locked=0
ro.boot.vbmeta.device_state=unlocked
ro.boot.verifiedbootstate=orange
ro.boot.veritymode=enforcing
```

The maintained procedure is [BOOTLOADER_UNLOCK.md](BOOTLOADER_UNLOCK.md).

## Persistent root

The final manager-paired KernelSU v0.9.5 boot image has SHA-256:

```text
F9A3DE1A4C377EA2871A03E6437F75F38BF4A0532A36A2418CA1BAE78DE78D70
```

Its complete 64 MiB hardware readback matched the candidate. Android booted normally and `/system/bin/su` returned `uid=0(root)` in SELinux context `u:r:su:s0`. The paired ARMv7 manager reported version `11872`; the ARMv7 `ksud` daemon persisted app grants. Root and the allowlist survived an ordinary reboot, after which Root Checker Basic passed.

The maintained procedure is [ROOT_WITH_KERNELSU.md](ROOT_WITH_KERNELSU.md). Final evidence is retained under `evidence/kernelsu-manager-pair-v3-20260901/`.

## Replay package

`release/ARUBA-REPLAY-MANIFEST.json` binds 23 required files by path, size, and SHA-256. On Linux, run:

```bash
./scripts/build-linux-tools.sh
python3 scripts/verify-release.py --check-linux-tool build/linux-tools/spd_dump
```

Require `verified_files=23` and `ARUBA_REPLAY_PACKAGE=PASS` before any hardware operation.
