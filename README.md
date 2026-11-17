# Synology DS115j on Debian

Install and operate Debian 13 (trixie, armhf) on the Synology DS115j
(Marvell Armada 370, 256 MiB RAM). This repository contains the boot files,
root filesystem payload, configuration, scripts, and recovery notes for the
device.

> **Start here:** follow the complete [UART installation and reinstall guide](docs/install-uart.md).
> It uses the supported, non-persistent U-Boot boot path and does not require
> SPI changes.

## What is included

The kernel image, ramdisks, and power-off module are a compatible set. Use the
files in `boot/` and `modules/` together; the kernel ABI is
`6.12.107+deb13-armmp`.

| File | SHA-256 | Purpose |
|---|---|---|
| `boot/uImage-ds115j` | `6b58d6eee97005845923167d5fe481035b7031195935bd632cdbe29ae75ed0f6` | Current kernel with appended DTB and USB VBUS fix |
| `boot/uRamdisk-hdd-ds115j` | `dbbd30ec2c3772e2816eaa5e3295b0580a357fc93458dcb3bf063bf7bf65cd75` | HDD boot; mounts `LABEL=rootfs` |
| `boot/uRamdisk-recovery-ds115j` | `cc9e6bc063a1247c3f370a87238f6ff544ff01ba145aed19f537b13d2810dd96` | BusyBox recovery environment |

Check the boot files from the repository root:

```bash
(cd boot && shasum -a 256 -c SHA256SUMS)
```

The Debian root filesystem is stored as two Git-friendly parts under `rootfs/`.
Reconstruct and verify the archive, and create the matching userspace install
kit, with:

```bash
scripts/reconstruct-rootfs.sh
```

The generated archives are ignored by Git. They are required by the documented
install flow and can be recreated from the tracked files.

The tracked root filesystem payload includes a shared bootstrap credential and
SSH host private keys. Treat both as compromised: change the root password over
UART and regenerate the host keys on the device before enabling network SSH.
This documentation-only cleanup does not remove sensitive material from the
payload or deployment defaults from scripts and configuration files. Review
those files before distributing the repository.

## Documentation

| Topic | Guide |
|---|---|
| Install or reinstall | [UART install guide](docs/install-uart.md) |
| Recovery and boot rollback | [Recovery runbook](docs/recovery.md) |
| Critical hardware and boot warnings | [Landmines](docs/landmines.md) |
| UART, network, and laptop setup | [Access](docs/access.md) |
| Current recorded device status | [Live-state notes](docs/current-state.md) |
| Reboot verification record | [Cold-boot verification](docs/cold-boot-verify.md) |
| Power button and MCU | [Power button](docs/power-button.md) |
| LEDs | [LED behavior](docs/led-behaviour.md), [SMART amber LED](docs/smart-amber-led.md) |
| HDD power management | [Disk idle](docs/disk-idle.md) |
| USB VBUS hardware fix | [USB VBUS fix](docs/usb-vbus-fix.md) |
| Optional configuration | [Optional tweaks](docs/optional-tweaks.md) |
| Debian versus DSM features | [OS feature comparison](docs/dsm-os-features.md) |

The live-state and verification documents are dated records, not a guarantee
that the NAS or TFTP server still has the same state. Recheck the device before
relying on a recorded result.

## Repository layout

- `boot/` — deployable kernel and ramdisks, with checksums.
- `config/` — system configuration and service files used by the installer.
- `dts/` — current board source and its matching DTB.
- `docs/` — installation, recovery, operation, and verification guides.
- `firmware/spi/` — read-only vendor firmware and supporting forensics.
- `modules/` — source and matching `qnap_poweroff_ds115j` kernel module.
- `rootfs/` — split Debian root filesystem archive and checksums.
- `scripts/` — provisioning, deployment, and device support tools.

## Safety essentials

- U-Boot boot files are on `ide 0:2` (`sda2`). **Never probe `ide 0:1`**; it
  hangs this device.
- Do not casually run `saveenv`, `sf write`, `bubt`, or `fw_setenv`. The U-Boot
  environment shares SPI space with the stock kernel.
- `scripts/extract-hdd.sh` is a destructive legacy utility retained for
  historical recovery workflows; do not run it on the live NAS.
- Do not attach disk-activity triggers to the bay's amber fault LED.
- Never publish credentials, host keys, MAC addresses, disk UUIDs, or private
  network details from a live device.

See the full [landmines list](docs/landmines.md) before using U-Boot or changing
the boot chain.

## Scope

The documented daily-ready setup covers HDD boot, SSH/networking, MCU LEDs and
beeper, temperature-based fan control, SMART fault indication, HDD idle
spindown, zram, time synchronization, and controlled power-off. Samba, backup
services, nftables, and burn-in testing are intentionally out of scope.
