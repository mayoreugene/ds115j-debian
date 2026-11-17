# Access and recovery connections

This guide describes the console and network access needed for installation
and recovery. It intentionally does not publish the original LAN addresses,
device MAC address, disk UUIDs, serial-adapter ID, or bootstrap password.

## Values to supply

Replace angle-bracketed values in commands before running them:

| Placeholder | Meaning |
|---|---|
| `<NAS_IP>` | Address assigned to the NAS on your LAN |
| `<LAPTOP_IP>` | Address of the laptop serving files |
| `<NETMASK>` | Netmask for the NAS/laptop network |
| `<GATEWAY_IP>` | LAN gateway, if required |
| `<NAS_MAC>` | MAC address printed on the specific NAS |
| `<SERIAL_DEVICE>` | UART adapter device path on your computer |

Review the network files under `config/` before installation. They may contain
deployment defaults and should match the target NAS and LAN.

## UART console

Use a **3.3 V TTL** adapter at **115200 baud, 8N1**. The console is UART0
(`ttyS0`). UART1 (`ttyS1`) connects to the Synology MCU; do not use it as a
console.

```bash
# Linux examples
sudo screen /dev/ttyACM0 115200
sudo screen /dev/ttyUSB0 115200

# macOS examples
screen /dev/cu.usbmodem* 115200
screen /dev/cu.usbserial-* 115200
```

On the six-pin header next to the fan connector:

| Pin | Signal | Connect to |
|---|---|---|
| 2 | GND | Adapter GND |
| 4 | NAS TX | Adapter RX |
| 6 | NAS RX | Adapter TX |
| 1, 3, 5 | Power/VCC | Leave unconnected |

Interrupt U-Boot during its countdown to reach the `Marvell>>` prompt. Close
stale `screen` sessions when finished so another process does not hold the
serial port.

A Raspberry Pi Pico can also act as the adapter with the
[pico-uart-bridge firmware](https://github.com/Noltari/pico-uart-bridge).
Connect Pico GND to pin 2, GPIO17/RX to pin 4, and GPIO16/TX to pin 6. Do not
connect VCC.

## U-Boot and TFTP

U-Boot uses `ide`, not `scsi`. Boot files are read from partition 2:

```text
ide reset
ext2load ide 0:2 0x01000000 /boot/uImage-ds115j
ext2load ide 0:2 0x02000000 /boot/uRamdisk-hdd-ds115j
bootm 0x01000000 0x02000000
```

**Never probe `ide 0:1`; this U-Boot hangs on that partition.** Do not save
U-Boot environment changes or write SPI as part of routine recovery. See
[landmines](landmines.md).

For TFTP, start `scripts/serve-tftp.sh` on the laptop, then set the addresses
for your LAN at the U-Boot prompt:

```text
setenv ipaddr <NAS_IP>
setenv serverip <LAPTOP_IP>
setenv netmask <NETMASK>
tftpboot 0x01000000 uImage-ds115j
tftpboot 0x02000000 uRamdisk-hdd-ds115j
bootm 0x01000000 0x02000000
```

Use `uRamdisk-recovery-ds115j` instead of the HDD ramdisk when you need the
BusyBox recovery environment. Serve only the boot files from this repository;
do not use an image without its appended DTB.

## Laptop services

| Port | Service | Start command |
|---|---|---|
| UDP 69 | TFTP | `scripts/serve-tftp.sh` |
| TCP 45151 | SPI dump receiver, when needed | `python3 scripts/spi-recv-daemon.py` |
| TCP 45152 | HTTP files for installation | Build with `sudo scripts/reconstruct-rootfs.sh`, then run `python3 -m http.server 45152 --bind <LAPTOP_IP> --directory "$PWD"` |

Bind temporary file servers only to a trusted LAN and stop them after use.
No DHCP, PXE, or NFS server is required by the documented workflow.

## Disk layout

The documented layout uses labels rather than fixed UUIDs:

| Partition | Filesystem | Label | Purpose |
|---|---|---|---|
| `sda1` | ext4 | `rootfs` | Debian root |
| `sda2` | ext2 | `boot` | U-Boot kernel and ramdisks |
| `sda3` | ext4 | `data` | `/srv/data`, if present |

This is a layout description, not a guarantee about a particular disk. Verify
device names and labels before any disk operation; do not format based only on
this table.

## Credentials

The rootfs build asks you to set its initial root password and creates fresh
SSH host keys. Use the password selected for that build. Do not expose
password-based root SSH to the Internet.
