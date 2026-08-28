# iMac18,3 CS8409 audio integration for Debian

This repository contains the Debian integration layer for restoring the
internal speakers on an iMac18,3 with the CS8409 / CS42L83 codec:

- module options;
- a small `hda-verb` speaker-enable script;
- a system service for applying the hardware settings;
- a PipeWire/PulseAudio user service that selects the analog output safely;
- an installer and an exportable integration patch.

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
installs it under `/lib/modules/$(uname -r)/updates/`, and installs only this
repository's scripts and configuration files.

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

## License

All files in this repository other than the `driver/` submodule are released
under the MIT License. The submodule retains its upstream license.
