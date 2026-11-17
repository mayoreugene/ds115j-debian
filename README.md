# Debian on Synology DS115j

This repository contains the board-specific files and tools for running Debian
13 (armhf) on a Synology DS115j with a Marvell Armada 370 SoC.

> **New installation?** Start with the [UART installation guide](docs/install-uart.md).
> Read the [safety notes](docs/landmines.md) before changing boot or disk state.

## Install

Build the Debian root filesystem on a Linux computer, then follow the UART
guide:

```bash
sudo scripts/reconstruct-rootfs.sh
```

The build uses Debian packages, asks you to choose a unique root password, and
generates fresh SSH host keys. The generated archives are ignored by Git.
See [build notes](docs/build-artifacts.md) for requirements, provenance, and
what can and cannot currently be rebuilt.

The old prebuilt rootfs has been removed from the current tree. Older Git
history, including upstream history, still contains that archive and its
shared bootstrap credential and SSH host keys. Treat those historical values
as compromised; removing a file from the current tree does not erase Git
objects.

## Boot image set

Keep the kernel, both ramdisks, and the matching power-off module together.
Their kernel ABI is `6.12.107+deb13-armmp`.

| File | SHA-256 | Purpose |
|---|---|---|
| `boot/uImage-ds115j` | `6b58d6eee97005845923167d5fe481035b7031195935bd632cdbe29ae75ed0f6` | Debian kernel with the DS115j DTB and USB VBUS fix |
| `boot/uRamdisk-hdd-ds115j` | `dbbd30ec2c3772e2816eaa5e3295b0580a357fc93458dcb3bf063bf7bf65cd75` | HDD boot |
| `boot/uRamdisk-recovery-ds115j` | `cc9e6bc063a1247c3f370a87238f6ff544ff01ba145aed19f537b13d2810dd96` | BusyBox recovery |

Verify the checked-in images:

```bash
(cd boot && shasum -a 256 -c SHA256SUMS)
```

On Linux, use `sha256sum -c SHA256SUMS` from inside `boot/`.

## Guides

| Need | Guide |
|---|---|
| Install or reinstall Debian | [UART installation](docs/install-uart.md) |
| Access UART and TFTP | [Access](docs/access.md) |
| Recover a failed boot | [Recovery](docs/recovery.md) |
| Rebuild the rootfs or inspect boot-image provenance | [Build notes](docs/build-artifacts.md) |
| Avoid known hardware and boot hazards | [Landmines](docs/landmines.md) |
| Understand recorded device tests | [Current state](docs/current-state.md), [cold-boot record](docs/cold-boot-verify.md) |
| Operate the power button, LEDs, or disk-idle behavior | [Power button](docs/power-button.md), [LEDs](docs/led-behaviour.md), [disk idle](docs/disk-idle.md) |
| Optional setup and hardware notes | [Optional tweaks](docs/optional-tweaks.md), [OS feature map](docs/dsm-os-features.md), [USB VBUS fix](docs/usb-vbus-fix.md) |

Recorded test results are historical, not a guarantee of the NAS's current
state. Verify the device before relying on them.

## Safety essentials

- U-Boot boot files are on `ide 0:2`. **Never probe `ide 0:1`**; it hangs this
  device.
- Do not casually run `saveenv`, `sf write`, `bubt`, or `fw_setenv`.
- The legacy [`scripts/extract-hdd.sh`](scripts/extract-hdd.sh) can erase the
  target disk. Do not use it for routine installation.
- Keep the fan enabled and the bay's amber LED reserved for faults.
