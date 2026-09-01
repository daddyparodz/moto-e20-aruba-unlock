# Command-only BootROM and custom recovery

This page separates what is proven from what is only technically plausible on the rooted ARUBA target.

## Command-only BootROM cycle

The retained U-Boot contains an explicit `AUTODLOADER_REBOOT` mode and an `autodloader` partition/mode string. Android's ADB reboot service can request that mode. The included helper arms the exact tested `spd_dump` listener first, then requests the reboot, loads the verified FDL chain, issues FDL2 `reset`, and waits for Android to return:

```powershell
# Phone-free validation only
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\cycle-bootrom.ps1

# Actual command-only cycle
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\cycle-bootrom.ps1 -Execute
```

The script performs no partition read, erase, or write. It verifies the target, build, root identity, transport executable, and both loaders before sending `adb reboot autodloader`. Exit is the FDL2 `reset` command, not a power-off, so a successful cycle needs no physical button.

Current status: the U-Boot mode and host sequence are evidence-backed, but the complete `-Execute` path has not yet been run on hardware because no ADB device was connected during implementation. Until `BOOTROM_COMMAND_CYCLE=PASS` is observed, treat physical Volume Up + Volume Down entry as the verified fallback.

## Is TWRP possible?

Potentially yes, but root alone does not make an arbitrary TWRP image compatible.

The captured partition map has A/B `boot`, `vendor_boot`, `dtb`, and `dtbo` partitions and no `recovery`, `recovery_a`, or `recovery_b` partition. Android's recovery architecture uses recovery-as-boot for this layout. Therefore:

- there is nowhere valid to run `fastboot flash recovery recovery.img`;
- an ARUBA TWRP port must be built as a boot/recovery-ramdisk image for the exact Android 11 boot-v2 layout;
- it must preserve the working kernel or deliberately integrate the KernelSU kernel, exact DTB/DTBO/vendor_boot relationship, AVB geometry, 32-bit recovery userspace, display/touch drivers, and ARUBA fstab;
- userdata decryption must be validated separately; a recovery that boots but cannot decrypt is only a partial port.

There is no verified official Moto E20 ARUBA TWRP image in this repository. Do not flash a generic Moto E20, Moto E-series, GKI, or Unisoc recovery image.

## Safe porting sequence

1. Capture and hash full `boot_a`, `boot_b`, `vendor_boot_a`, `dtb_a`, and `dtbo_a` before modification.
2. Extract the exact boot-v2 geometry, ramdisk, kernel command line, fstab, and device properties.
3. Create an ARUBA device tree against the TWRP Android 11/12.1 source base.
4. Build recovery-as-boot while preserving the verified KernelSU kernel as the first compatibility candidate.
5. Validate image size, boot header, AVB footer/descriptors, DTB/DTBO relationship, and non-ramdisk regions offline.
6. Test only with a complete inactive-slot backup and a proven BootROM restore path; do not overwrite the working `boot_a` first.
7. Accept installation only after touch, display, ADB, storage mounts, encryption behavior, reboot-to-system, and KernelSU persistence are verified.

No TWRP image is supplied yet because those device-tree and hardware gates have not been completed. This is a real porting project, not an APK-style installation enabled by root.

References: [AOSP recovery image layouts](https://source.android.com/docs/core/architecture/bootloader/recovery-images), [AOSP A/B ramdisk partitions](https://source.android.com/docs/core/architecture/partitions/ramdisk-partitions), and [TWRP's Android 10+ minimal manifest](https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp).
