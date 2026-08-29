# iMac18,3 CS8409 audio integration for Debian

This repository contains the Debian integration layer for restoring the
internal speakers on an iMac18,3 with the CS8409 / CS42L83 codec:

- module options;
- a small `hda-verb` speaker-enable script;
- a system service for applying the hardware settings;
- a PipeWire/PulseAudio user service that selects the analog output safely;
- an installer and an exportable integration patch;
- a minimal driver patch that prevents the Apple CS8409 path from exposing
  the unsafe generic `Auto-Mute Mode` callback.

## Maintainer

Integration and documentation: [Gnomsa](https://github.com/gnomsa)
([gnomsa88@gmail.com](mailto:gnomsa88@gmail.com)).

## Driver provenance

The `driver/` directory is a Git submodule, pinned to commit
[`d8c9001`](https://github.com/egorenar/snd-hda-codec-cs8409/commit/d8c9001418e6172099a0907f022534f152e29d71)
from [egorenar/snd-hda-codec-cs8409](https://github.com/egorenar/snd-hda-codec-cs8409).
It is an external, out-of-tree driver and is **not authored or maintained by
this repository**. No driver C source or binary is copied into this project.
Consult that upstream project for its license, authorship, and support policy.

## Install

Use a working network connection, then clone including the submodule:

```sh
git clone --recurse-submodules https://github.com/gnomsa/snd-hda-codec-cs8409-imac18.git
cd snd-hda-codec-cs8409-imac18
sudo ./scripts/install.sh
```

The installer builds the pinned external module against the running kernel,
first applies the repository's automute fix, installs the resulting module
under `/lib/modules/$(uname -r)/updates/`, and installs only this repository's
scripts and configuration files.

Build dependencies on Debian:

```sh
sudo apt install build-essential linux-headers-$(uname -r) git alsa-tools xz-utils
```

Reboot after installation. Do not hot-reload the CS8409 module while PipeWire
or WirePlumber is active: this can leave the audio session blocked.

After signing back in, enable the per-user output selector once:

```sh
systemctl --user enable --now cs8409-select-analog-output.service
```

## Verify

```sh
aplay -l
```

The relevant line should be similar to:

```text
card 0: PCH [HDA Intel PCH], device 0: CS8409/CS42L83 Analog
```

Then select **CS8409/CS42L83 Analog** in the desktop audio settings. The user
service only chooses an existing analog sink; it never falls back to a GPU HDMI
sink, because a moving level meter on a disconnected HDMI port does not mean
that the internal speakers are receiving sound.

Confirm that the patched module is selected:

```sh
modinfo -F filename snd-hda-codec-cs8409
```

The path should be under `/lib/modules/$(uname -r)/updates/`.
The installer compresses the module with an XZ CRC32 integrity check, matching
Debian's kernel-module format. XZ's default CRC64 check is not accepted by this
kernel's in-kernel module decompressor.

## Auto-Mute failure after reboot

The failure fixed by patch `0002` has the following characteristic symptoms:

- sound worked after manually enabling the codec, but disappeared after a
  reboot;
- the desktop volume meter continued moving while the speakers were silent;
- WirePlumber became stuck while opening or releasing an ALSA control;
- the kernel log showed `automute_mode_put`, `call_update_outputs`, or a fault
  reached through an invalid callback address.

The level meter moves because PipeWire is still receiving the playback stream.
It does not prove that samples reach the CS8409 physical output. At session
startup WirePlumber restores saved mixer state, including `Auto-Mute Mode` when
the external driver exposes it. The Apple driver path already handles jack
routing itself; entering the generic automute callback can wedge the HDA control
path.

Patch `0002` sets `suppress_auto_mute` before generic HDA parsing and clears the
generic automute hooks. This prevents creation and restoration of the unsafe
control while leaving the driver's own unsolicited jack-event path in place.

If WirePlumber is already in uninterruptible `D` state, restarting PipeWire or
rebinding the codec cannot reliably recover that boot. Install the corrected
module and reboot. Do not repeatedly unbind the PCI HDA device or codec from
sysfs once the control path is wedged.

See [Troubleshooting](docs/troubleshooting.md) for diagnostic commands and safe
recovery steps.

## Updating the kernel

The external module must be rebuilt for every new kernel:

```sh
cd snd-hda-codec-cs8409-imac18
git submodule update --init --recursive
sudo ./scripts/install.sh
sudo reboot
```

## Patch-only use

`patches/0001-imac18-cs8409-integration.patch` contains only the integration
files authored for this repository. It contains no driver source, firmware, or
compiled module.

`patches/0002-cs8409-apple-disable-generic-automute.patch` is the minimal
driver change authored by Gnomsa. It applies to the pinned external driver at
commit `d8c9001`; the patch contains only changed context and does not copy the
driver source tree. Apply it from inside the external driver's checkout:

```sh
git apply ../patches/0002-cs8409-apple-disable-generic-automute.patch
```

The installer applies this patch automatically and skips it when the target
assignment is already absent.

## License

Copyright (c) 2026 Gnomsa. All files authored for this repository, including
the integration scripts, documentation, and patch `0002`, are released under
the MIT License. The `driver/` submodule is external and retains its upstream
copyright and license.
