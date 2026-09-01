#!/usr/bin/env python3
"""Rebuild the exact ARUBA SPL-unlock payload from the trusted stock SPL.

This removes the old opaque gen_spl-unlock.exe dependency from reproduction.
The hardware-verified payload differs from the trusted 65,416-byte stock SPL
only by sixteen AArch64 NOP instructions across four verified 16-byte ranges.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "files" / "recovery" / "stock-spl.bin"
DEFAULT_OUTPUT = ROOT / "files" / "unlock" / "spl-unlock.bin"
REFERENCE = ROOT / "files" / "unlock" / "spl-unlock.bin"
EXPECTED_SIZE = 65416
EXPECTED_STOCK_SHA256 = "895FC2EDD262857E48D9472D117AFB63668D17820A289F1E51E57696FE403F77"
EXPECTED_UNLOCK_SHA256 = "2DFE4FC1D5B82768B78247D51A98BE5874A10A54264AAA165D2D2D5639CEF2DB"
NOP = bytes.fromhex("1f2003d5")
WORD_OFFSETS = (
    0xA380, 0xA384, 0xA388, 0xA38C,
    0xA4A0, 0xA4A4, 0xA4A8, 0xA4AC,
    0xA4CC, 0xA4D0, 0xA4D4, 0xA4D8,
    0xA4F8, 0xA4FC, 0xA500, 0xA504,
)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    source = args.input.read_bytes()
    source_hash = sha256(source)
    if len(source) != EXPECTED_SIZE:
        raise SystemExit(f"stock SPL size mismatch: {len(source)} != {EXPECTED_SIZE}")
    if source_hash != EXPECTED_STOCK_SHA256:
        raise SystemExit(f"stock SPL SHA256 mismatch: {source_hash} != {EXPECTED_STOCK_SHA256}")

    patched = bytearray(source)
    for offset in WORD_OFFSETS:
        patched[offset:offset + 4] = NOP
    output = bytes(patched)

    diffs = [i for i, (a, b) in enumerate(zip(source, output)) if a != b]
    expected_diffs = [i for offset in WORD_OFFSETS for i in range(offset, offset + 4) if source[i] != NOP[i - offset]]
    if diffs != expected_diffs:
        raise SystemExit(f"unexpected SPL diff layout: actual={diffs} expected={expected_diffs}")

    output_hash = sha256(output)
    if output_hash != EXPECTED_UNLOCK_SHA256:
        raise SystemExit(f"rebuilt unlock SHA256 mismatch: {output_hash} != {EXPECTED_UNLOCK_SHA256}")

    if REFERENCE.is_file() and output != REFERENCE.read_bytes():
        raise SystemExit("rebuilt SPL does not byte-match the committed hardware-verified payload")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(output)

    print("ARUBA_SPL_UNLOCK_REBUILD=PASS")
    print(f"source_sha256={source_hash}")
    print(f"output_sha256={output_hash}")
    print(f"patched_instruction_count={len(WORD_OFFSETS)}")
    print(f"changed_byte_count={len(diffs)}")
    print("reference_byte_match=YES" if REFERENCE.is_file() else "reference_byte_match=NOT_CHECKED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
