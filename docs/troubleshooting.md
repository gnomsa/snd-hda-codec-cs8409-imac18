# Troubleshooting CS8409 audio on iMac18,3

Copyright (c) 2026 Gnomsa. Released under the MIT License.

## Silent speakers with a moving level meter

A moving Plasma, PulseAudio, or PipeWire level meter only confirms that an
application is producing samples. Check that the CS8409 analog device exists:

```sh
aplay -l
wpctl status
```

The ALSA list should contain `CS8409/CS42L83 Analog`. In `wpctl status`, make
sure the default sink is that analog device rather than a GPU HDMI output.

## Confirm the out-of-tree module

```sh
uname -r
modinfo -F filename snd-hda-codec-cs8409
modinfo -F vermagic snd-hda-codec-cs8409
```

The module filename should be below the running kernel's `updates/` directory,
and `vermagic` must start with the exact output of `uname -r`. Reinstall after
every kernel update.

If `systemd-modules-load` reports `Invalid argument`, check for an unsupported
XZ integrity method:

```sh
journalctl -b -k | grep 'decompression failed'
xz -lv /lib/modules/$(uname -r)/updates/snd-hda-codec-cs8409.ko.xz
```

The check must be `CRC32`, not XZ's default `CRC64`. The repository installer
always emits CRC32-compressed modules.

## Detect the Auto-Mute callback failure

```sh
ps -eo pid,state,wchan:32,comm | grep -E 'wireplumber|pipewire'
journalctl -b -k | grep -E 'automute|call_update_outputs|snd_ctl|BUG:|Oops:'
```

WirePlumber in `D` state together with an automute-related kernel fault means
the problem is inside the current kernel session. Killing or restarting the
userspace processes is insufficient because the ALSA control release itself is
blocked.

## Safe recovery

From a clean checkout, rebuild and install the patched module:

```sh
git submodule update --init --recursive
sudo ./scripts/install.sh
sudo reboot
```

After login:

```sh
systemctl --user enable --now cs8409-select-analog-output.service
aplay -l
wpctl status
```

Avoid hot-unbinding `hdaudioC0D0` or PCI device `0000:00:1f.3` when
WirePlumber is already in `D` state. Those operations can block in
`snd_ctl_remove` or driver attach and still require a reboot.

## Useful service logs

```sh
systemctl status cs8409-enable-speakers.service
journalctl -b -u cs8409-enable-speakers.service
systemctl --user status cs8409-select-analog-output.service
journalctl --user -b -u cs8409-select-analog-output.service
```

The system service enables the internal speaker pins and amplifier GPIO. The
user service selects an already existing CS8409 analog sink; it does not create
an ALSA device and does not treat HDMI as a fallback.
