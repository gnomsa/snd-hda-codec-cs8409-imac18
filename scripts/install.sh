#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

if (( EUID != 0 )); then
  echo 'Run as root: sudo ./scripts/install.sh' >&2
  exit 1
fi

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
kernel=$(uname -r)

command -v make >/dev/null || { echo 'make is required' >&2; exit 1; }
command -v xz >/dev/null || { echo 'xz is required (package: xz-utils)' >&2; exit 1; }
[[ -d "/lib/modules/$kernel/build" ]] || { echo "Missing headers for $kernel" >&2; exit 1; }
[[ -f "$root_dir/driver/Makefile" ]] || { echo 'Driver submodule is missing; run git submodule update --init --recursive' >&2; exit 1; }

automute_patch="$root_dir/patches/0002-cs8409-apple-disable-generic-automute.patch"
if grep -q 'spec->gen.automute_hook = cs_8409_automute;' \
  "$root_dir/driver/patch_cirrus_apple.h"; then
  git -C "$root_dir/driver" apply "$automute_patch"
fi

make -C "$root_dir/driver"
module_tmp=$(mktemp)
trap 'rm -f "$module_tmp"' EXIT
xz --check=crc32 -c "$root_dir/driver/snd-hda-codec-cs8409.ko" >"$module_tmp"
install -D -m 0644 "$module_tmp" \
  "/lib/modules/$kernel/updates/snd-hda-codec-cs8409.ko.xz"
rm -f "/lib/modules/$kernel/updates/snd-hda-codec-cs8409.ko"
depmod -a "$kernel"

install -D -m 0644 "$root_dir/config/modprobe.d/imac18-speaker.conf" /etc/modprobe.d/imac18-speaker.conf
install -D -m 0644 "$root_dir/config/modprobe.d/cs8409-no-powersave.conf" /etc/modprobe.d/cs8409-no-powersave.conf
install -D -m 0755 "$root_dir/scripts/enable-speakers.sh" /usr/local/libexec/cs8409-imac18/enable-speakers.sh
install -D -m 0755 "$root_dir/scripts/select-analog-output.sh" /usr/local/libexec/cs8409-imac18/select-analog-output.sh
install -D -m 0644 "$root_dir/systemd/cs8409-enable-speakers.service" /etc/systemd/system/cs8409-enable-speakers.service
install -D -m 0644 "$root_dir/systemd/cs8409-select-analog-output.service" /etc/systemd/user/cs8409-select-analog-output.service

systemctl daemon-reload
systemctl enable cs8409-enable-speakers.service

echo 'Installed. Reboot, then enable the per-user output selector once:'
echo '  systemctl --user enable --now cs8409-select-analog-output.service'
