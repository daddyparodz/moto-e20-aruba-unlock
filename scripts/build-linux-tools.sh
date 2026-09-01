#!/usr/bin/env bash
set -euo pipefail

readonly revision=fa0becf5e3f026b3b99103c65de6eb9a8348b27c
readonly repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly source_dir="${repo_root}/build/spreadtrum_flash"
readonly output_dir="${repo_root}/build/linux-tools"

for command in git make cc pkg-config file install sha256sum; do
  command -v "${command}" >/dev/null || {
    echo "Missing build dependency: ${command}" >&2
    exit 1
  }
done
pkg-config --exists libusb-1.0 || {
  echo "Missing libusb development files (Ubuntu: libusb-1.0-0-dev)." >&2
  exit 1
}

mkdir -p "${repo_root}/build" "${output_dir}"
if [[ ! -d "${source_dir}/.git" ]]; then
  git clone https://github.com/TomKing062/spreadtrum_flash.git "${source_dir}"
fi
make -C "${source_dir}" clean >/dev/null
git -C "${source_dir}" fetch --quiet origin "${revision}"
git -C "${source_dir}" checkout --quiet --detach "${revision}"
test "$(git -C "${source_dir}" rev-parse HEAD)" = "${revision}"
if [[ -n "$(git -C "${source_dir}" status --porcelain)" ]]; then
  echo "Pinned transport checkout is dirty; refusing to build." >&2
  exit 1
fi
make -C "${source_dir}" clean all
install -m 0755 "${source_dir}/spd_dump" "${output_dir}/spd_dump"
install -m 0644 "${repo_root}/files/bootrom/windows-tools/custom_exec_no_verify_65015f08.bin" "${output_dir}/"
install -m 0644 "${repo_root}/files/bootrom/windows-tools/misc-wipe.bin" "${output_dir}/"

help_output="$("${output_dir}/spd_dump" --help 2>&1 || true)"
grep -Fq "sha1:${revision}" <<<"${help_output}"
file "${output_dir}/spd_dump"
echo "LINUX_TRANSPORT_BUILD=PASS"
echo "source_revision=${revision}"
sha256sum "${output_dir}/spd_dump"
