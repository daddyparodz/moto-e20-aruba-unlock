#!/usr/bin/env python3
"""Rebuild every ARUBA-specific binary used by the verified v3 unlock.

The output is accepted only if every artifact matches the exact identity used by
the successful hardware transaction. No phone access is performed here.
"""

from __future__ import annotations

import argparse
import hashlib
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUT_ROOT = ROOT / "source" / "unlock"
DEFAULT_OUTPUT = ROOT / "files" / "unlock"
NOP = bytes.fromhex("1f2003d5")

FDL1_INPUT = INPUT_ROOT / "fdl1-stock.bin"
FDL2_INPUT = INPUT_ROOT / "fdl2-stock.bin"
STOCK_SPL = ROOT / "files" / "recovery" / "stock-spl.bin"

FDL1_SOURCE_SHA = "1300593D3772E1E999CA8D3B79F97DC098225612D45906DDE07707C683187C2D"
FDL2_SOURCE_SHA = "3C12C9673B103CC281E6C0F66E840531A2AB4636714E78E66D597DF4A4977E73"

EXPECTED_OUTPUTS = {
    "fdl1.bin": (60664, "98A308E4C755219D592288EB668117B938C3435783DD5E0F75E450CDCE5A3076"),
    "fdl2.bin": (1159000, "5BCAE75A8E3A940B294F46DDE2CD8FC5817A89A0544C917437A500A9188F03B3"),
    "spl-unlock.bin": (65416, "2DFE4FC1D5B82768B78247D51A98BE5874A10A54264AAA165D2D2D5639CEF2DB"),
    "uboot-unlock.bin": (1159000, "F16385309B5F2538D406207411D09B3D02DE23B341E5A10602BF458DFED7E5B3"),
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def read_exact(path: Path, size: int, digest: str) -> bytearray:
    data = path.read_bytes()
    actual = sha256(data)
    if len(data) != size:
        raise SystemExit(f"{path}: size {len(data)} != {size}")
    if actual != digest:
        raise SystemExit(f"{path}: SHA256 {actual} != {digest}")
    return bytearray(data)


def u32_le(data: bytearray, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def patch_words(data: bytearray, expected_words: dict[int, int], label: str) -> bytes:
    for offset, expected in expected_words.items():
        actual = u32_le(data, offset)
        if actual != expected:
            raise SystemExit(
                f"{label}: instruction mismatch at 0x{offset:X}: 0x{actual:08X} != 0x{expected:08X}"
            )
        data[offset:offset + 4] = NOP
    return bytes(data)


def build_fdl1(output: Path) -> None:
    data = read_exact(FDL1_INPUT, 60664, FDL1_SOURCE_SHA)
    output.write_bytes(
        patch_words(
            data,
            {0x9F5C: 0x940000A7, 0x9F60: 0x34000040, 0x9F64: 0x14000000},
            "FDL1",
        )
    )


def build_fdl2(output: Path) -> None:
    data = read_exact(FDL2_INPUT, 1159000, FDL2_SOURCE_SHA)
    if u32_le(data, 0x7F990) != 0x52800020:
        raise SystemExit("FDL2: expected MOV W0,#1 at 0x7F990 is missing")
    output.write_bytes(
        patch_words(
            data,
            {
                0x0697C: 0x94021A8A,
                0x7F97C: 0xAA1403E1,
                0x7F980: 0x97FFDD2C,
                0x7F984: 0x34000080,
                0x7F988: 0xF8408E60,
                0x7F98C: 0xB5FFFF60,
            },
            "FDL2",
        )
    )


def run_checked(*args: str) -> None:
    print("+", " ".join(args))
    subprocess.run(args, cwd=ROOT, check=True)


def verify_output(path: Path, expected_size: int, expected_hash: str) -> tuple[int, str]:
    data = path.read_bytes()
    actual_hash = sha256(data)
    if len(data) != expected_size:
        raise SystemExit(f"{path.name}: size {len(data)} != {expected_size}")
    if actual_hash != expected_hash:
        raise SystemExit(f"{path.name}: SHA256 {actual_hash} != {expected_hash}")
    return len(data), actual_hash


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    print("=== ARUBA v3 exact reproducible rebuild ===")

    fdl1_out = output_dir / "fdl1.bin"
    fdl2_out = output_dir / "fdl2.bin"
    spl_out = output_dir / "spl-unlock.bin"
    cboot_out = output_dir / "uboot-unlock.bin"

    build_fdl1(fdl1_out)
    build_fdl2(fdl2_out)

    run_checked(
        sys.executable,
        str(ROOT / "scripts" / "build-unlock-spl.py"),
        "--input",
        str(STOCK_SPL),
        "--output",
        str(spl_out),
    )
    run_checked(
        sys.executable,
        str(ROOT / "scripts" / "build-unlock-uboot.py"),
        "--output",
        str(cboot_out),
    )

    manifest_lines = ["ARUBA V3 REBUILD MANIFEST", "=========================", ""]
    for name in sorted(EXPECTED_OUTPUTS):
        size, digest = EXPECTED_OUTPUTS[name]
        actual_size, actual_hash = verify_output(output_dir / name, size, digest)
        print(f"PASS {name} size={actual_size} sha256={actual_hash}")
        manifest_lines.extend([name, f"size={actual_size}", f"sha256={actual_hash}", ""])

    (output_dir / "SHA256SUMS.txt").write_text("\n".join(manifest_lines), encoding="utf-8")
    print("ARUBA_V3_REBUILD=PASS")
    print(f"output_dir={output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
