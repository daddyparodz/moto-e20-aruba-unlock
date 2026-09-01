# Artifacts, backups, and recovery

The authoritative inventory is `release/ARUBA-REPLAY-MANIFEST.json`. Verify it before selecting any file.

## Operational files

- `files/bootrom/windows-tools/`: exact tested `spd_dump` transport bundle.
- `files/bootrom/windows-driver/`: signed UNISOC driver used for USB `1782:4d00`.
- `files/unlock/`: exact unlock payloads.
- `files/root/`: final rooted kernel, boot image, paired manager, daemon, AVB material, and build reports.
- `source/`: exact unlock inputs plus the modified KernelSU v0.9.5 manager/userspace source.

## Stock recovery files

| Item | Retained path | SHA-256 |
|---|---|---|
| Stock `boot_a` | `files/recovery/stock-boot.img` | `9C7A2A089E0E97D683ACCD095FFF0DADC95B37C1AF2533E5854925FD4791E7C2` |
| Stock SPL | `files/recovery/stock-spl.bin` | `895FC2EDD262857E48D9472D117AFB63668D17820A289F1E51E57696FE403F77` |
| Stock U-Boot | `files/recovery/stock-uboot.bin` | `776471A810A4A79B6A5B0084BCE6C1F9E0D40D3F32069D0486E370BB3FD65C56` |

## Hardware evidence

- `evidence/kernelsu-manager-pair-v3-20260901/boot_a-prewrite-v2.img.xz`: complete image immediately before the final V3 write.
- `evidence/kernelsu-manager-pair-v3-20260901/boot_a-v3-readback.img.xz`: complete hardware readback of the final rooted image.
- Text records in that directory capture prewrite, write/readback, runtime, manager, Root Checker, and reboot-persistence results.
- `evidence/persistent-root-20260901/` retains the compact textual chronology of earlier booting and failed candidates without duplicating hundreds of megabytes of superseded images.

## Recovery order

1. Confirm the exact target, active slot, storage type, and failed partition.
2. Restore the immediately preceding full readback when available.
3. To return `boot_a` to factory state, use only the stock image and hash above.
4. If unlock was interrupted, restore stock U-Boot first, then both stock SPL copies, and verify complete readbacks before leaving BootROM.
5. Never substitute an image from another phone, firmware, slot, or storage layout.

Historical build outputs remain recoverable from Git history and named handoff branches; they are intentionally excluded from the finished checkout because they are not part of the verified replay path.
