# Included source

`kernelsu-v0.9.5/` is a source snapshot of KernelSU tag `v0.9.5`, commit `b766b98513b5a7eb33bc1c4a76b5702bf1288f07`. It contains the upstream `manager` and `userspace` trees plus the three ARUBA changes used to produce the retained 32-bit manager and daemon:

1. build manager JNI only for `armeabi-v7a`;
2. provide sufficient Gradle heap for the build;
3. enable the Rust `arm` target in `ksud`'s `getpwnam` path.

The upstream GPL-3.0 license is retained at `kernelsu-v0.9.5/LICENSE`.
`ARUBA-CHANGES.patch` contains the complete diff from the pinned upstream commit.

Run `build-kernelsu-armv7.ps1` from Windows PowerShell after installing JDK 21, Android SDK/NDK 26.3.11579264, Rust, and the `armv7-linux-androideabi` Rust target.

The repository intentionally does not contain the private Android debug signing key. Therefore a newly built APK has a different certificate and will not be recognized by the already-flashed paired kernel. Use the retained APK for the verified replay path; pair a new kernel trust hash before using a newly signed manager.
