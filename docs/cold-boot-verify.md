# Historical boot verification

> **Test record from 2026-09-16, with image updates noted through 2026-09-20.**
> This is not a current health check. It records one warm reboot and earlier
> observations; it did not repeat a PSU-cut cold boot in that session.

## Result

The device completed a reboot from its HDD boot partition into Debian 13
(`6.12.107+deb13-armmp`). SSH returned, no systemd units were failed, the
network and data volume were available, and the fan controller operated
without setting its target to zero.

The recorded checks also covered SMART, chrony/RTC, zram, the MCU boot
sequence, and the power-off module. Samba, backups, nftables, and burn-in were
outside the test scope.

## Limits of this test

- The session tested `reboot`, **not** a shutdown that cuts PSU power followed
  by a physical button power-on.
- The kernel image later received the USB VBUS device-tree fix. See the
  [README](../README.md) for the checked-in boot images and hashes.
- The TFTP server and the NAS were not necessarily on the same image version
  during the original test. Check hashes before recovery or deployment.
- Old IP addresses, MAC addresses, disk UUIDs, process IDs, and exact console
  timestamps are intentionally omitted. They identify one installation and
  are not needed to repeat the checks.

## Repeat the checks

Use the [installation guide](install-uart.md) and [recovery runbook](recovery.md)
for current procedures. On a running NAS, verify:

```bash
systemctl --failed
systemctl is-active networking chrony syno-fan.service
findmnt /srv/data
swapon --show
smartctl -H /dev/sda
lsmod | grep qnap_poweroff
```

For a true PSU-cut test, remain at the chassis: issue `poweroff` only when
someone can press the physical power button afterward. Do not remotely power
off a device that must be recovered manually.
