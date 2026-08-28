#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

device=/dev/snd/hwC0D0

if ! command -v hda-verb >/dev/null; then
  echo 'hda-verb is required (package: alsa-tools)' >&2
  exit 1
fi

for _ in $(seq 1 10); do
  [[ -e "$device" ]] && break
  sleep 1
done

if [[ ! -e "$device" ]]; then
  echo "CS8409 codec device not found: $device" >&2
  exit 1
fi

# Enable the two internal-speaker pins and Apple amplifier GPIO lines.
for pin in 0x24 0x25; do
  hda-verb "$device" "$pin" SET_PIN_WIDGET_CONTROL 0x40
  hda-verb "$device" "$pin" SET_EAPD_BTLENABLE 0x02
  hda-verb "$device" "$pin" SET_AMP_GAIN_MUTE 0x00
done

hda-verb "$device" 0x01 SET_GPIO_MASK 0x03
hda-verb "$device" 0x01 SET_GPIO_DIRECTION 0x03
hda-verb "$device" 0x01 SET_GPIO_DATA 0x03
