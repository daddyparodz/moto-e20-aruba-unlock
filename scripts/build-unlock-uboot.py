#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import hashlib
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "files" / "recovery" / "stock-uboot.bin"
DEFAULT_OUTPUT = ROOT / "files" / "unlock" / "uboot-unlock.bin"

EXPECTED_SOURCE_SIZE = 1159000
EXPECTED_SOURCE_SHA256 = "776471A810A4A79B6A5B0084BCE6C1F9E0D40D3F32069D0486E370BB3FD65C56"

DO_CBOOT = 0x73A4
PATCH_SITE = 0x73DC
SET_LOCK_STATUS = 0x80DA0
POWERDOWN_FALLBACK = 0x7490
EXPECTED_ORIGINAL = bytes.fromhex("8afeff977f0a0071c1000054")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def encode_branch(from_file: int, to_file: int, link: bool) -> bytes:
    delta = to_file - from_file
    if delta % 4:
        raise ValueError("branch target is not instruction aligned")
    imm26 = delta // 4
    if not -(1 << 25) <= imm26 < (1 << 25):
        raise ValueError("branch target is out of AArch64 B/BL range")
    word = (0x94000000 if link else 0x14000000) | (imm26 & 0x03FFFFFF)
    return struct.pack("<I", word)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    output_path = args.output.resolve()
    source = SOURCE.read_bytes()
    source_hash = sha256(source)
    if len(source) != EXPECTED_SOURCE_SIZE:
        raise SystemExit(f"Source size mismatch: {len(source)}")
    if source_hash != EXPECTED_SOURCE_SHA256:
        raise SystemExit(f"Source SHA256 mismatch: {source_hash}")

    original = source[PATCH_SITE:PATCH_SITE + len(EXPECTED_ORIGINAL)]
    if original != EXPECTED_ORIGINAL:
        raise SystemExit(
            f"Original patch-site bytes mismatch: {original.hex()} != {EXPECTED_ORIGINAL.hex()}"
        )

    patch = (
        bytes.fromhex("20008052")
        + encode_branch(PATCH_SITE + 4, SET_LOCK_STATUS, True)
        + encode_branch(PATCH_SITE + 8, POWERDOWN_FALLBACK, False)
    )
    if len(patch) != len(EXPECTED_ORIGINAL):
        raise SystemExit("Internal patch length error")

    candidate = bytearray(source)
    candidate[PATCH_SITE:PATCH_SITE + len(patch)] = patch
    candidate = bytes(candidate)

    if candidate[PATCH_SITE:PATCH_SITE + len(patch)] != patch:
        raise SystemExit("Candidate patch block mismatch after write")

    diffs = [i for i, (a, b) in enumerate(zip(source, candidate)) if a != b]
    expected_positions = [
        PATCH_SITE + i
        for i, (a, b) in enumerate(zip(EXPECTED_ORIGINAL, patch))
        if a != b
    ]
    if diffs != expected_positions:
        raise SystemExit(
            f"Unexpected diff positions: actual={diffs} expected={expected_positions}"
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(candidate)
    candidate_hash = sha256(candidate)

    print("=== ARUBA U-Boot unlock generator ===")
    print(f"source_sha256={source_hash}")
    print(f"output_sha256={candidate_hash}")
    print(f"patch_site_file=0x{PATCH_SITE:X}")
    print(f"original_bytes={EXPECTED_ORIGINAL.hex()}")
    print(f"patch_bytes={patch.hex()}")
    print(f"diff_byte_count={len(diffs)}")
    print(f"diff_positions={','.join(f'0x{x:X}' for x in diffs)}")
    print(f"diff_first=0x{diffs[0]:X}")
    print(f"diff_last=0x{diffs[-1]:X}")
    print(f"output={output_path}")


if __name__ == "__main__":
    main()
