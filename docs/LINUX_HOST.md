# Native Linux host guide

Linux can perform the complete ARUBA workflow. Python rebuilds the exact unlock files, `spd_dump` uses native libusb, PowerShell 7 runs the guarded unlock transaction, and Android Platform Tools handle the post-boot checks and manager installation. No Windows driver, DLL, or Windows executable is required on this route.

The final unlock and root binaries are identical to the hardware-tested Windows run. The host transport is rebuilt from the same `spd_dump` source revision. The Linux transport has been compiled and statically tested on Ubuntu x86-64; an actual ARUBA transaction from Linux remains a hardware-validation gate.

## 1. Host prerequisites

On Ubuntu or Debian:

```bash
sudo apt-get update
sudo apt-get install git build-essential pkg-config libusb-1.0-0-dev python3 adb xz-utils
```

Install PowerShell 7 (`pwsh`) from Microsoft's package repository if you intend to run the guarded bootloader-unlock transaction. CI does not need PowerShell because it never contacts a phone.

## 2. Build and verify

```bash
git clone https://github.com/daddyparodz/moto-e20-aruba-unlock.git
cd moto-e20-aruba-unlock
./scripts/build-linux-tools.sh
python3 scripts/build-unlock-files.py
python3 scripts/verify-release.py --check-linux-tool build/linux-tools/spd_dump
```

Require `LINUX_TRANSPORT_BUILD=PASS`, `ARUBA_V3_REBUILD=PASS`, `verified_files=23`, and `ARUBA_REPLAY_PACKAGE=PASS`. The native executable must report source revision `fa0becf5e3f026b3b99103c65de6eb9a8348b27c`; its binary SHA-256 is compiler/libc-dependent and is not the durable identity.

## 3. USB access

The smartphone path must use libusb, not the Linux USB-serial fallback. Install the supplied udev rule:

```bash
sudo install -m 0644 files/bootrom/linux-udev/99-aruba-bootrom.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

After entering BootROM, verify that `lsusb` shows `1782:4d00`. Log out and back in if your distribution does not immediately apply `TAG+="uaccess"`. As a diagnostic only, run `spd_dump` with `sudo`; do not run the entire repository as root.

## 4. Guarded bootloader unlock

Prepare a writable transport directory:

```bash
mkdir -p /tmp/aruba-unlock-tools
cp build/linux-tools/spd_dump build/linux-tools/custom_exec_no_verify_65015f08.bin \
  build/linux-tools/misc-wipe.bin /tmp/aruba-unlock-tools/
chmod 0755 /tmp/aruba-unlock-tools/spd_dump

pwsh -NoProfile -File scripts/unlock-bootloader.ps1 \
  -StaticPrecheckOnly -WorkDir /tmp/aruba-unlock-tools \
  -FdlDir "$(pwd)/files/unlock"
```

Require `V3 STATIC PRECHECK RESULT: PASS`. Then follow the physical-entry, read-only live-precheck, execute, and Android verification gates in [the canonical unlock guide](BOOTLOADER_UNLOCK.md), replacing `powershell.exe` with `pwsh` and using the Linux paths above. The guarded script selects `spd_dump` rather than `spd_dump.exe` automatically.

## 5. KernelSU root

After unlock, use the same native transport directory. Start an interactive FDL2 session:

```bash
cd /tmp/aruba-unlock-tools
./spd_dump --wait 3600 \
  exec_addr 0x65015f08 \
  fdl /absolute/repo/path/files/unlock/fdl1.bin 0x65000800 \
  fdl /absolute/repo/path/files/unlock/fdl2.bin 0x9efffe00 \
  exec
```

At `FDL2 >`, follow the backup, exact-hash, `boot_a` write, full readback, and recovery gates in [the canonical root guide](ROOT_WITH_KERNELSU.md). Linux equivalents are `stat`, `sha256sum`, `cp`, and absolute `/.../boot.img` paths. Manager installation and persistence checks use the same cross-platform `adb` commands.

Do not attach a phone to the GitHub Actions runner. The self-hosted workflow performs source compilation and offline verification only.
