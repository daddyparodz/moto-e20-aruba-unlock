# Repository instructions

This repository documents a completed, hardware-verified Moto E20 ARUBA bootloader unlock and KernelSU root procedure. Treat the checked-in guides and hashes as the source of truth.

## Before changing anything

1. Read `README.md`, `docs/KNOWN-FAILURES.md`, and the guide relevant to the change.
2. Run `./scripts/build-linux-tools.sh`, then `python3 scripts/verify-release.py --check-linux-tool build/linux-tools/spd_dump` on Linux.
3. Preserve exact hashes, negative results, recovery files, and provenance.
4. Do not present another model, firmware, storage type, slot, loader, address, or partition as compatible without separate hardware evidence.

## Canonical procedures

- `docs/BOOTLOADER_UNLOCK.md` is the only maintained bootloader-unlock guide.
- `docs/ROOT_WITH_KERNELSU.md` is the only maintained root guide.
- `docs/KNOWN-FAILURES.md` records routes that must not be repeated.
- `docs/ARTIFACTS-AND-RECOVERY.md` identifies recovery material and retained evidence.
- `docs/BOOTROM-AND-RECOVERY.md` tracks command-only BootROM and custom-recovery feasibility.

Do not turn historical Git commits, branches, filenames, or failed experiments into alternative instructions. Do not silently replace a verified binary with a same-named rebuild: require the documented size and SHA-256.

## Contribution rules

- Keep the public workflow understandable from a fresh clone.
- Update the replay manifest and verifier whenever a required file changes.
- Validate Markdown links and run `git diff --check` before committing.
- Keep hardware-facing commands guarded by exact target, slot, size, and hash checks.
- Never include private signing keys, personal device data, account credentials, or USB debugging keys.
- Commit focused changes with clear messages; do not rewrite shared history.

This project concerns an owner-controlled device. It does not document carrier-lock, account-lock, FRP, authentication, anti-theft, or third-party access-control bypasses.
