# DS115j recovery runbook

Use this guide to restore bootability using U-Boot, the local boot partition,
or laptop TFTP. Replace `<NAS_IP>`, `<LAPTOP_IP>`, and `<NETMASK>` with values
for your LAN before running commands.

> **Critical:** never probe `ide 0:1`; this U-Boot hangs on that partition.
> Do not casually run `saveenv`, write SPI, or reformat a partition. Keep the
> U-Boot environment untouched and use known-good images.

See the [access guide](access.md) for UART and laptop setup, and the
[landmines](landmines.md) before changing boot or disk state.

## Boot image set

Use the checked-in kernel and ramdisks listed in the [README](../README.md).
The kernel has an appended device tree; do not use an image without its DTB.
The kernel image, HDD ramdisk, and `qnap_poweroff_ds115j` module must match.
Verify image checksums before copying or booting.

## NAS running, SSH unavailable

1. Connect to UART0 and interrupt U-Boot if necessary.
2. After Linux starts, log in on the serial console and inspect:

   ```sh
   ip -4 addr
   ip route
   systemctl --failed
   ```

3. If DHCP is configured, renew it with `dhclient -v eth0`. Do not run
   `ifdown eth0` or restart networking blindly from the only remote session.
4. Restore the network settings for your LAN if needed. Confirm access at
   `root@<NAS_IP>`.

## NAS fails to boot

At the `Marvell>>` prompt, use the known-good files on partition 2:

```text
ide reset
ext2load ide 0:2 0x01000000 /boot/uImage-ds115j
ext2load ide 0:2 0x02000000 /boot/uRamdisk-hdd-ds115j
bootm 0x01000000 0x02000000
```

If the HDD root filesystem cannot start, use
`uRamdisk-recovery-ds115j` instead of the HDD ramdisk.

### TFTP fallback

Run `scripts/serve-tftp.sh` on the laptop, then at U-Boot:

```text
setenv ipaddr <NAS_IP>
setenv serverip <LAPTOP_IP>
setenv netmask <NETMASK>
tftpboot 0x01000000 uImage-ds115j
tftpboot 0x02000000 uRamdisk-recovery-ds115j
bootm 0x01000000 0x02000000
```

Do not use `uImage-nodtb`. A TFTP boot still uses the HDD root when the HDD
ramdisk is loaded; the recovery ramdisk starts BusyBox instead.

## Boot partition damaged

Boot the recovery ramdisk over TFTP. Inspect the disk and partition labels
before making changes:

```sh
cat /proc/partitions
blkid
```

If partition 2 (`LABEL=boot`) exists but its ext2 filesystem needs repair,
unmount it and run `e2fsck -f /dev/sda2`. If it is clean or repaired, mount it,
restore the checked boot files from the laptop, verify their SHA-256 hashes,
then `sync` and unmount.

Do not recreate the partition table or format a partition unless you have
confirmed the layout and have a separate backup of any data to preserve.
Never touch the root or data partitions as part of boot-file recovery.

## Versioned boot deployment

`scripts/deploy-boot.sh` can list and deploy versioned boot bundles. Read its
usage and inspect the selected image before using any rollback action. A
`prev` operation may select an obsolete image; do not deploy it without
verifying its checksum and device-tree contents. Keep UART available for
recovery.

## Post-recovery checks

```sh
uname -r
systemctl --failed
ip -4 addr show eth0
findmnt /
findmnt /srv/data
swapon --show
lsmod | grep qnap_poweroff
```

Check the kernel release against the module ABI and compare boot-file hashes
with the [repository manifest](../boot/SHA256SUMS). Record what changed and
whether recovery touched the root, boot, data, U-Boot, or SPI storage.
