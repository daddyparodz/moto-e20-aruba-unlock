# KernelSU v0.9.5 build provenance

The exact hardware-flashed image is retained for replay. This page records how it was produced; a fresh build is an audit artifact, not a drop-in replacement, because absolute paths influence this legacy ThinLTO build.

## Pinned source environment

| Component | Version or identity |
|---|---|
| Motorola kernel source | commit `3b4ca0fee2002a4940b0d9e86ebf8dac96eac418` |
| KernelSU | v0.9.5, commit `b766b98513b5a7eb33bc1c4a76b5702bf1288f07` |
| KernelSU kernel tree | `5e812e1dd436ab63529266d67ca239570f2d144c` |
| Android Clang | r383902 / LLVM `b397f81060ce6d701042b782172ed13bee898b79` |
| Production config SHA-256 | `E2A51353FFA79141041468E367C7DBF43EE5DA9AF9242911877EE0DCE8D22183` |
| Android NDK | 26.3.11579264 |
| CMake / Gradle | 3.22.1 / 8.7 |
| JDK | Android Studio JBR 21 |
| Rust target | `armv7-linux-androideabi` |

The full final output directory retains construction commands, kernel provenance, boot-v2 checks, AVB descriptors, authentication checks, public keys, and SHA-256 records:

```text
files/root/
```

The paired kernel trust values were:

```text
KSU_EXPECTED_SIZE=0x02e8
KSU_EXPECTED_HASH=aefd00026b3486f740412bc4fb0605ff1bd84d23b41f1ca0760626e386d0dd3b
```

## ARMv7 manager and daemon

ARUBA has a 64-bit kernel but a 32-bit Android userspace. The v0.9.5 manager ABI filter was extended with `armeabi-v7a`. `userspace/ksud` was built for `armv7-linux-androideabi`, Android API 26, using `patches/kernelsu-v095-ksud-armv7.patch`, and embedded as `lib/armeabi-v7a/libksud.so`.

Final retained identities:

| File | Size | SHA-256 |
|---|---:|---|
| `files/root/ksud` | 3472028 | `504DBBE6439F82F5624A891DF31885FACB74FAA1AD89FCC302968842403A8AD5` |
| `files/root/manager.apk` | 21297954 | `57FB4AAEFF55D4B8A0428738399CCF3D27153FC7F3BC50565B7EDFB291B90AF2` |

The modified source and a Windows build helper are retained under [`source/`](../source/README.md).

A differently signed manager requires a newly paired kernel. Never commit a private signing key.
