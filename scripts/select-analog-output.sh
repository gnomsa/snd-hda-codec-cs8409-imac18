#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

for _ in $(seq 1 20); do
  sink=$(pactl list short sinks 2>/dev/null | awk '$2 ~ /pci-0000_00_1f.3/ && $2 ~ /analog-stereo/ {print $2; exit}')
  [[ -n "${sink:-}" ]] && break
  sleep 1
done

if [[ -z "${sink:-}" ]]; then
  echo 'CS8409 analog sink was not found; not changing the default output.' >&2
  exit 1
fi

pactl set-default-sink "$sink"
pactl set-sink-mute "$sink" false
pactl set-sink-volume "$sink" 70%
