# Recorded system status

> **Historical snapshot, not a live health check.** The baseline was recorded
> on 2026-09-16, with later tests added through 2026-09-21. Addresses,
> services, boot files, and device state may have changed since then. Verify
> the NAS directly before relying on any result.

## Summary of recorded results

| Area | Recorded result |
|---|---|
| Debian boot | HDD boot from U-Boot partition 2; kernel ABI `6.12.107+deb13-armmp` |
| Device tree | `alarm-gpios` absent; USB VBUS regulator fix included in the documented current image |
| Network | Ethernet and DHCP/static fallback were tested; use the local network configuration, not old addresses in this log |
| Data volume | `LABEL=data` mounted at `/srv/data` |
| SMART and bay LED | SMART monitoring active; amber reserved for fault indication |
| Time and memory | chrony and zram active; journal size limited |
| Fan and MCU | temperature-controlled fan and boot LED/beeper sequence tested |
| Power button | PIC event handling and controlled power-off verified on 2026-09-21; see [power-button.md](power-button.md) |
| Watchdog | systemd watchdog feeding verified on 2026-09-21 |
| RTC scheduled wake | Tested and did not wake the device after the PSU-cut shutdown path; do not rely on it |
| Optional services | Samba, backups, nftables, and burn-in were outside the recorded scope |

## Boot image notes

The repository's [README](../README.md) lists the current checked-in image
hashes. The historical probe recorded a period when the NAS disk and TFTP
server were not on the same image version. This log does not establish their
present state; verify hashes on the device before deploying or rolling back.

Kernel image, HDD ramdisk, and `qnap_poweroff_ds115j` module are a compatible
set. Do not perform a routine kernel upgrade without rebuilding and validating
the whole set.

## Safe re-check

From a trusted network, connect using the address configured for the NAS:

```bash
ssh root@<NAS_IP>
systemctl --failed
systemctl is-active syno-fan.service networking chrony
journalctl -u syno-fan.service -b --no-pager
sha256sum /srv/tftp/uImage-ds115j
test -e /sys/firmware/devicetree/base/gpio-fan/alarm-gpios && echo BAD || echo ABSENT
```

The final command checks the running device tree; compare the TFTP image hash
with the repository before booting it.
