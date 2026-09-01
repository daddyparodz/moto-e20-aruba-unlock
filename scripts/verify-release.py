#!/usr/bin/env python3
"""Verify every exact-target file required by the maintained ARUBA replay guide."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "release" / "ARUBA-REPLAY-MANIFEST.json"
EXPECTED_MARKER = "fa0becf5e3f026b3b99103c65de6eb9a8348b27c"
GUIDE_FILES = (
    ROOT / "README.md",
    ROOT / "release" / "README.md",
    ROOT / "docs" / "ROOT_WITH_KERNELSU.md",
    ROOT / "docs" / "BOOTLOADER_UNLOCK.md",
    ROOT / "docs" / "ARTIFACTS-AND-RECOVERY.md",
    ROOT / "docs" / "KNOWN-FAILURES.md",
    ROOT / "docs" / "KERNELSU-BUILD.md",
    ROOT / "docs" / "BOOTROM-AND-RECOVERY.md",
    ROOT / "docs" / "LINUX_HOST.md",
    ROOT / "source" / "README.md",
)
LOCAL_LINK = re.compile(r"(?<!!)\[[^]]*\]\(([^)#]+)(?:#[^)]*)?\)")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--check-windows-tool", action="store_true")
    parser.add_argument("--check-linux-tool", type=Path)
    args = parser.parse_args()

    manifest_path = args.manifest.resolve()
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    failures: list[str] = []

    for entry in data["files"]:
        path = ROOT / entry["path"]
        if not path.is_file():
            failures.append(f"MISSING {entry['path']}")
            continue
        actual_size = path.stat().st_size
        if actual_size != entry["size"]:
            failures.append(
                f"SIZE {entry['path']} expected={entry['size']} actual={actual_size}"
            )
            continue
        actual_hash = sha256(path)
        if actual_hash != entry["sha256"].upper():
            failures.append(
                f"SHA256 {entry['path']} expected={entry['sha256']} actual={actual_hash}"
            )
            continue
        print(f"PASS {entry['role']}: {entry['path']}")

    for guide in GUIDE_FILES:
        if not guide.is_file():
            failures.append(f"MISSING GUIDE {guide.relative_to(ROOT)}")
            continue
        for match in LOCAL_LINK.finditer(guide.read_text(encoding="utf-8")):
            target = match.group(1)
            if target.startswith(("http://", "https://")):
                continue
            if not (guide.parent / target).resolve().exists():
                failures.append(
                    f"BROKEN LINK {guide.relative_to(ROOT)} -> {target}"
                )
        print(f"PASS guide links: {guide.relative_to(ROOT)}")

    if args.check_windows_tool:
        if sys.platform != "win32":
            failures.append("--check-windows-tool requires Windows")
        else:
            tool_dir = ROOT / "files" / "bootrom" / "windows-tools"
            completed = subprocess.run(
                [str(tool_dir / "spd_dump.exe"), "--help"],
                cwd=tool_dir,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=15,
                check=False,
            )
            if EXPECTED_MARKER not in completed.stdout:
                failures.append("spd_dump source marker missing from --help output")
            else:
                print(f"PASS spd_dump source marker: {EXPECTED_MARKER}")

    if args.check_linux_tool:
        tool = args.check_linux_tool.resolve()
        if sys.platform == "win32":
            failures.append("--check-linux-tool requires Linux or another Unix host")
        elif not tool.is_file():
            failures.append(f"Linux spd_dump not found: {tool}")
        else:
            completed = subprocess.run(
                [str(tool), "--help"],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=15,
                check=False,
            )
            if EXPECTED_MARKER not in completed.stdout:
                failures.append("Linux spd_dump source marker missing from --help output")
            else:
                print(f"PASS native Linux spd_dump source marker: {EXPECTED_MARKER}")

    if failures:
        print("ARUBA_REPLAY_PACKAGE=FAIL", file=sys.stderr)
        for failure in failures:
            print(f"FAIL {failure}", file=sys.stderr)
        return 1

    print(f"verified_files={len(data['files'])}")
    print("ARUBA_REPLAY_PACKAGE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
