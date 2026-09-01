# ARUBA replay package

This directory is the integrity entry point for the exact Moto E20 `aruba` result. Operational binaries are organized under `files/`, modified source under `source/`, and hardware results under `evidence/`.

From a fresh clone, verify every required file:

```bash
./scripts/build-linux-tools.sh
python3 scripts/verify-release.py --check-linux-tool build/linux-tools/spd_dump
```

Expected terminal lines:

```text
verified_files=23
ARUBA_REPLAY_PACKAGE=PASS
```

Then read [known failures](../docs/KNOWN-FAILURES.md) and choose the single guide for your current state:

- [Unlock the bootloader](../docs/BOOTLOADER_UNLOCK.md) on an exact-match locked phone.
- [Root with KernelSU](../docs/ROOT_WITH_KERNELSU.md) only after unlock is verified.

The JSON manifest binds the supported target and every operational/recovery artifact to an exact size and SHA-256.

The package deliberately distinguishes:

- hardware-tested retained binaries;
- deterministic unlock outputs;
- the exact hardware-flashed rooted boot image;
- manager and ARMv7 daemon control-plane files;
- stock recovery inputs and full-partition readbacks.

Android Platform Tools remain a host installation prerequisite. Linux uses native libusb and the rule under `files/bootrom/linux-udev/`; the exact working Windows bundle remains retained as historical hardware evidence. No PAC download is required for the retained exact-target replay package. See [the Linux host guide](../docs/LINUX_HOST.md).
