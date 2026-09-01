# Unlock the Motorola Moto E20 ARUBA bootloader

This is the single maintained bootloader-unlock procedure for the exact hardware path that was successfully executed and independently verified on the tested Motorola Moto E20. Read this guide and [known failures](KNOWN-FAILURES.md) completely before writing anything.

The older v1, v2, first cboot, and FDL1-RAM experiments are historical only. Do not reproduce them as the final method.

## Verified target and result

Tested target:

- Motorola Moto E20
- SKU `XT2155-3`
- codename `aruba`
- Unisoc `ums9230`
- eMMC
- Android 11
- installed build during the verified unlock: `RONS31.267-94-14`
- active slot during the verified transaction: `a`

Verified final state after stock boot-chain restoration and a normal Android boot:

```text
ro.boot.flash.locked=0
ro.boot.vbmeta.device_state=unlocked
ro.boot.verifiedbootstate=orange
ro.boot.veritymode=enforcing
```

`flash.locked=0` plus `vbmeta.device_state=unlocked` is the independent completion gate. The orange Verified Boot state is expected for an unlocked bootloader. `veritymode=enforcing` does not mean the bootloader is locked.

The successful v3 hardware evidence is preserved in:

```text
analysis/ARUBA-V3-HARDWARE-UNLOCK-SUCCESS-20260821.txt
```

Do not rerun the unlock transaction on a phone that is already verified unlocked.

## Important risk boundary

This procedure temporarily erases both on-disk SPL copies and temporarily writes the active U-Boot partition. It is intentionally guarded and restores the exact stock U-Boot and both exact stock SPL copies before the phone is powered off.

Expect a factory-reset/data-loss boundary from bootloader unlocking. Back up anything important first.

Do not substitute loaders, stock images, addresses, hashes, or a different device model. If any preflight hash or stock-chain readback differs, stop.

## The short version

The final workflow is:

1. clone this repository;
2. verify and rebuild the ARUBA-specific unlock artifacts, requiring byte-for-byte hardware-verified hashes;
3. prepare the retained exact `spd_dump` build and helper blobs;
4. enter Unisoc BootROM/download mode once;
5. run the read-only live precheck;
6. run the guarded v3 transaction exactly once;
7. boot normal Android;
8. verify the two unlock properties above.

The guarded runner is PowerShell 7 and works with the native Linux transport as well as the retained Windows transport. See [the native Linux host guide](LINUX_HOST.md).

## 1. Clone and rebuild every ARUBA-specific artifact

From Windows PowerShell with Python 3 installed:

```powershell
git clone https://github.com/daddyparodz/moto-e20-aruba-unlock.git
cd .\moto-e20-aruba-unlock

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\build-unlock-files.ps1
```

Cross-platform equivalent:

```bash
python3 scripts/build-unlock-files.py
```

The rebuild must finish with:

```text
ARUBA_V3_REBUILD=PASS
```

It writes the independently rebuilt artifacts under:

```text
files/unlock/
```

Required final identities:

| Artifact | Size | SHA256 |
|---|---:|---|
| `fdl1.bin` | 60664 | `98A308E4C755219D592288EB668117B938C3435783DD5E0F75E450CDCE5A3076` |
| `fdl2.bin` | 1159000 | `5BCAE75A8E3A940B294F46DDE2CD8FC5817A89A0544C917437A500A9188F03B3` |
| `spl-unlock.bin` | 65416 | `2DFE4FC1D5B82768B78247D51A98BE5874A10A54264AAA165D2D2D5639CEF2DB` |
| `uboot-unlock.bin` | 1159000 | `F16385309B5F2538D406207411D09B3D02DE23B341E5A10602BF458DFED7E5B3` |

The build is not accepted merely because files exist. Every output is hash-checked against the exact v3 bytes used by the successful hardware transaction.

## 2. Prepare the retained transport tools

Verify the complete replay manifest, then copy the retained hardware-tested Windows bundle to a writable working directory:

```powershell
python .\scripts\verify-release.py --check-windows-tool
$tools = 'C:\aruba-unlock-tools'
New-Item -ItemType Directory -Force $tools | Out-Null
Copy-Item .\files\bootrom\windows-tools\* $tools -Force
$fdl = (Resolve-Path .\files\unlock).Path
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\unlock-bootloader.ps1 `
  -StaticPrecheckOnly -WorkDir $tools -FdlDir $fdl
```

The tested `spd_dump` source/build marker is:

```text
fa0becf5e3f026b3b99103c65de6eb9a8348b27c
```

Require `V3 STATIC PRECHECK RESULT: PASS`. The verifier checks that `spd_dump.exe --help` reports that exact SHA1 marker and validates `Channel9.dll`, `Channel.ini`, the helper, and cleanup blob. Run `spd_dump` from `$tools`; another current directory can fail to resolve its DLL or helper.

If the BootROM interface has no compatible driver, install the retained hardware-tested package from an Administrator PowerShell:

```powershell
pnputil /add-driver .\files\bootrom\windows-driver\sprdvcom.inf /install
```

Upstream source project:

```text
https://github.com/TomKing062/spreadtrum_flash
```

Durable source checkout for reproduction:

```bash
git clone https://github.com/TomKing062/spreadtrum_flash.git
git -C spreadtrum_flash checkout fa0becf5e3f026b3b99103c65de6eb9a8348b27c
```

The two required helper blobs have these exact identities:

```text
custom_exec_no_verify_65015f08.bin
size   96
SHA256 32D8B796FF484C168D7FC63D9ED75D056D0833B55C7D65FBDAF2C548474F3C62

misc-wipe.bin
SHA256 BD6B67E852D6072E6FB87040F2AC40216D5B661B7FA661E7024569ECF8DDB3A7
```

The original Unisoc unlock helper project is:

```text
https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
```

The final ARUBA FDL and cboot binaries are not universal upstream device binaries. They are rebuilt from the exact Motorola ARUBA inputs and patches documented below.

## 3. Enter ARUBA BootROM/download mode

1. Power the phone completely off.
2. Hold **Volume Up + Volume Down**.
3. Connect USB while continuing to hold both buttons.
4. The tested Windows system enumerated the device as `SPRD U2S Diag`, USB VID/PID `1782:4d00`.

On this handset, holding both volume buttons longer than expected improved connection reliability.

If Windows does not expose the interface to `spd_dump`, install a compatible Unisoc/libusb driver for the `1782:4d00` interface before continuing.

## 4. Run the read-only live precheck

From the repository root:

```powershell
$tools = "C:\aruba-unlock-tools"
$fdl = (Resolve-Path .\files\unlock).Path

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\unlock-bootloader.ps1 `
  -LivePrecheckOnly `
  -WorkDir $tools `
  -FdlDir $fdl
```

Require:

```text
V3 LIVE PRECHECK RESULT: PASS
```

The precheck is read-only. It proves before destructive work that:

- active U-Boot matches the trusted stock hash;
- `splloader` matches the trusted stock SPL;
- `splloader_bak` matches the trusted stock SPL;
- the live 64-byte lock record is one of the known accepted pre-v3 states;
- every static input and v3 patch byte matches the verified identity.

If the precheck does not pass, do not run `-Execute`.

## 5. Execute the final guarded v3 transaction

Re-enter BootROM/download mode if the read-only precheck powered the phone off, then run:

```powershell
$tools = "C:\aruba-unlock-tools"
$fdl = (Resolve-Path .\files\unlock).Path

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\unlock-bootloader.ps1 `
  -Execute `
  -WorkDir $tools `
  -FdlDir $fdl
```

Do not manually repeat Stage 3. The guarded script intentionally runs `spl-unlock` once only.

### What the script does

The verified ordering is fixed:

1. open one retained patched-FDL2 session;
2. read and hash-check stock `splloader`, `splloader_bak`, active U-Boot, and the lock record;
3. erase `splloader` and `splloader_bak`;
4. read both erased areas back and verify the exact erased hash;
5. write the exact v3 cboot candidate to active U-Boot;
6. read it back and require the exact candidate hash;
7. reset only after both SPL copies are proven erased and candidate U-Boot is proven written;
8. execute `spl-unlock.bin` exactly once from BootROM;
9. automatically reconnect to BootROM;
10. capture the post-v3 64-byte record;
11. restore exact stock U-Boot first;
12. restore exact stock `splloader`;
13. restore exact stock `splloader_bak`;
14. write the validated `misc-wipe.bin` cleanup;
15. read back and hash-check restored U-Boot and both restored SPL copies;
16. capture the record again and require it not to change during restoration;
17. power the phone off only after stock restoration is verified.

The successful run observed a non-zero `spd_dump` exit during the one-shot SPL stage because the USB device disappeared as control transitioned. That specific one-shot stage is not automatically retried.

## 6. Boot Android normally and verify unlock

Boot the phone normally. After Android starts and ADB is authorized:

```powershell
adb shell getprop ro.boot.flash.locked
adb shell getprop ro.boot.vbmeta.device_state
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.veritymode
```

The verified result is:

```text
0
unlocked
orange
enforcing
```

You may also inspect Fastboot state as a secondary check if desired, but the repository's v3 completion gate is the independent normal-Android evidence above.

## 7. Exact rebuild details

This section records how the final artifacts were built so another researcher can reproduce the exact bytes instead of downloading unexplained binaries.

### Stock Motorola inputs

Reference PAC used for ARUBA secure-chain loaders:

```text
RONS31.267-94-17_2311_20231109_user_SIGN_027.pac
Product: ums9230_4h10_go
```

Exact loader inputs committed in the repository:

```text
source/unlock/fdl1-stock.bin
size   60664
SHA256 1300593D3772E1E999CA8D3B79F97DC098225612D45906DDE07707C683187C2D

source/unlock/fdl2-stock.bin
size   1159000
SHA256 3C12C9673B103CC281E6C0F66E840531A2AB4636714E78E66D597DF4A4977E73
```

Exact stock restore inputs dumped from the tested live `RONS31.267-94-14` phone and later restoration-verified:

```text
files/recovery/stock-spl.bin
size   65416
SHA256 895FC2EDD262857E48D9472D117AFB63668D17820A289F1E51E57696FE403F77

files/recovery/stock-uboot.bin
size   1159000
SHA256 776471A810A4A79B6A5B0084BCE6C1F9E0D40D3F32069D0486E370BB3FD65C56
```

### ARUBA FDL1 patch

`scripts/patch-fdl1.ps1` verifies the exact stock input and replaces three AArch64 instructions with NOPs:

```text
0x9F5C  940000A7 -> D503201F
0x9F60  34000040 -> D503201F
0x9F64  14000000 -> D503201F
```

Result:

```text
SHA256 98A308E4C755219D592288EB668117B938C3435783DD5E0F75E450CDCE5A3076
```

### ARUBA FDL2 transport patch

`scripts/patch-fdl2.ps1` verifies the exact stock input and NOPs:

```text
0x0697C  94021A8A -> D503201F
0x7F97C  AA1403E1 -> D503201F
0x7F980  97FFDD2C -> D503201F
0x7F984  34000080 -> D503201F
0x7F988  F8408E60 -> D503201F
0x7F98C  B5FFFF60 -> D503201F
```

It additionally requires the existing `MOV W0,#1` at `0x7F990`.

Result:

```text
SHA256 5BCAE75A8E3A940B294F46DDE2CD8FC5817A89A0544C917437A500A9188F03B3
```

### Exact SPL-unlock rebuild

The original experiment used the upstream `gen_spl-unlock` helper. Repository verification later proved the final payload differs from trusted stock SPL by exactly sixteen AArch64 NOP instructions, 64 changed bytes total, at:

```text
0xA380 0xA384 0xA388 0xA38C
0xA4A0 0xA4A4 0xA4A8 0xA4AC
0xA4CC 0xA4D0 0xA4D4 0xA4D8
0xA4F8 0xA4FC 0xA500 0xA504
```

`scripts/build-unlock-spl.py` rebuilds that exact payload directly from the trusted stock SPL and requires byte equality with the committed hardware-verified reference.

Result:

```text
SHA256 2DFE4FC1D5B82768B78247D51A98BE5874A10A54264AAA165D2D2D5639CEF2DB
```

This means reproduction no longer depends on trusting an opaque prebuilt `gen_spl-unlock.exe`.

### Final v3 cboot build

`scripts/build-unlock-uboot.py` starts from the trusted live U-Boot SHA256:

```text
776471A810A4A79B6A5B0084BCE6C1F9E0D40D3F32069D0486E370BB3FD65C56
```

At file offset `0x73DC`, the exact original 12 bytes are:

```text
8a fe ff 97 7f 0a 00 71 c1 00 00 54
```

The generator replaces that block with AArch64 semantics:

```text
MOV W0,#1
BL  set_lock_status        ; target file offset 0x80DA0
B   powerdown_fallback     ; target file offset 0x7490
```

The patch is encoded programmatically, not copied as an unexplained blob. The generator verifies source size/hash, original bytes, branch ranges, exact changed offsets, and final output hash.

Final v3 candidate:

```text
files/unlock/uboot-unlock.bin
size   1159000
SHA256 F16385309B5F2538D406207411D09B3D02DE23B341E5A10602BF458DFED7E5B3
```

This is the candidate used by the verified v3 hardware transaction.

## 8. Successful v3 evidence and exact record transition

Verified hardware transaction directory on the original Windows host:

```text
V3_TRANSACTION_20260821-113646
```

The exact runner used was:

```text
scripts/unlock-bootloader.ps1
canonical LF SHA256 2AB6381B887E1CAFF19C648AD7A4EF80D7F3EF439B52D9384DB16D7C02417936
```

The persistent 64-byte record changed from the known historical pre-v3 value:

```text
8AF340B74CEDDF8D6F3614850B122693899F414B3A17C19FD306D1B9E9A0C0A0
```

to:

```text
C59B9923FFF8DE7183D9F715530E900EC8D8E2604591290FD7C33693BB3FE852
```

and remained at that hash after stock U-Boot/SPL restoration.

That record transition is supporting evidence. The authoritative unlock-completion proof is the independent normal-Android boot properties shown above.

Relevant final authorization run recorded by the project:

```text
run 32467611005
job 96727467427
conclusion success
Stop containers success
```

## 9. Recovery boundary

The guarded v3 runner is designed to restore stock state before returning control whenever possible.

Trusted recovery identities:

```text
stock U-Boot
SHA256 776471A810A4A79B6A5B0084BCE6C1F9E0D40D3F32069D0486E370BB3FD65C56

stock SPL, written to both splloader and splloader_bak
SHA256 895FC2EDD262857E48D9472D117AFB63668D17820A289F1E51E57696FE403F77
```

If both SPL copies have been erased, do not attempt a normal boot. Keep the phone in or return it to the Unisoc BootROM path and restore exact stock U-Boot plus both stock SPL copies before doing anything else.

Do not substitute stock images from another firmware or another phone merely because the model name matches.

## 10. Superseded and prohibited unlock routes

The following are not the final procedure:

- v1 unlock transaction;
- v2 unlock transaction;
- historical FDL1-RAM v2 route;
- the older `fdl2-cboot-aruba.bin` candidate SHA256 `13A4F4E0F74A8A7C782CD734D8BE86D786FFED0086EAC5909C8C5E753FFBAD27`;
- repeated execution of `spl-unlock` because a one-shot transport process returned non-zero.

Use the maintained builders, verified candidate hash, and `scripts/unlock-bootloader.ps1` only.

## Final status

```text
ARUBA_BOOTLOADER_UNLOCK=VERIFIED_COMPLETE
FINAL_UNLOCK_METHOD=V3
STOCK_UBOOT_RESTORED_AND_VERIFIED=YES
STOCK_SPLLOADER_RESTORED_AND_VERIFIED=YES
STOCK_SPLLOADER_BAK_RESTORED_AND_VERIFIED=YES
NORMAL_ANDROID_FLASH_LOCKED=0
NORMAL_ANDROID_VBMETA_DEVICE_STATE=unlocked
```

Bootloader-unlock research for this exact tested path is complete. Current project work should treat unlock as a finished prerequisite and focus on the remaining root objective.
