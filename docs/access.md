# ACCESS — NAS, laptop, UART, services

Trusted LAN only. Do not publish these details off-LAN.

## Systems

| Role | Host / IP | How |
|---|---|---|
| **NAS (Debian)** | `ds115j` **`192.168.68.233/22`** | `ssh root@192.168.68.233` password **`ds115j`** |
| NAS DHCP (when lease exists) | historically **`192.168.68.62/22`** | same credentials; **as of 2026-09-15 19:50 UTC the lease had expired and `.62` was gone** |
| **Laptop (operator-chosen)** | example **`192.168.68.251/22`** | cloned repository; TFTP via `scripts/serve-tftp.sh` |
| Gateway / DNS | **`192.168.68.1`** | default route; DNS also `1.1.1.1` |
| NAS MAC | **`00:11:32:4d:c3:b8`** | pinned by `.link` + ifupdown `pre-up` |
| Netmask | `255.255.252.0` (`/22`) | |

Owner preference: root/password SSH is acceptable on this LAN. Keep it LAN-only. Do not expose SSH to the Internet.

## UART console access

```bash
# Linux (e.g. Fedora, Ubuntu):
sudo screen /dev/ttyACM0 115200   # Pico USB CDC
sudo screen /dev/ttyUSB0 115200   # FTDI / CH340 / CP2102

# macOS:
screen /dev/cu.usbmodem* 115200   # Pico USB CDC
screen /dev/cu.usbserial* 115200  # FTDI / CH340 / CP2102
```

- Console is UART0 / `ttyS0`, 115200 8N1.
- Interrupt U-Boot during the 3-second countdown → `Marvell>>`.
- **Motherboard 6-pin Header (next to fan):**
  - **Pin 2:** GND (labeled on PCB)
  - **Pin 4:** TX (NAS transmit, 3.3V TTL - middle pin)
  - **Pin 6:** RX (NAS receive, 3.3V TTL - labeled on PCB)
  - Pins 1, 3, 5: Not connected (3.3V VCC)
- **Raspberry Pi Pico as UART bridge:** You can flash [Noltari/pico-uart-bridge](https://github.com/Noltari/pico-uart-bridge) onto a Raspberry Pi Pico. Connect Pico GND $\leftrightarrow$ Pin 2, Pico GPIO17 / Pin 22 (UART0 RX) $\leftrightarrow$ Pin 4 (TX), Pico GPIO16 / Pin 21 (UART0 TX) $\leftrightarrow$ Pin 6 (RX). Do not connect 3.3V/VCC.
- **Never leave a foreign/root `screen` holding this device.** Check and kill stale sessions before another operator needs UART.
- UART1 / `ttyS1` is the Synology PIC MCU (power-off, status LED, beeper). Do not hijack it for a second console.

## U-Boot / TFTP recovery addresses

```text
NAS ipaddr:     192.168.68.233
Laptop serverip:192.168.68.251
Netmask:        255.255.252.0
Gateway:        192.168.68.1
Kernel load:    0x01000000
Ramdisk load:   0x02000000
```

Conceptual **current** local boot (do not rewrite `bootcmd` just to pretty-print; `printenv bootcmd` first):

```text
ide reset
ext2load ide 0:2 0x01000000 /boot/uImage-ds115j
ext2load ide 0:2 0x02000000 /boot/uRamdisk-hdd-ds115j
bootm 0x01000000 0x02000000
```

Kernel cmdline:

```text
console=ttyS0,115200 earlyprintk root=LABEL=rootfs rootwait rw panic=10
```

**NEVER** `ext2ls` / `ext2load` / probe **`ide 0:1`**. This U-Boot hangs. Use **`ide 0:2` only**. Disk command is **`ide`**, not `scsi`.

Laptop TFTP recovery (`scripts/serve-tftp.sh` must be running):

```text
tftpboot 0x01000000 uImage-ds115j
tftpboot 0x02000000 uRamdisk-hdd-ds115j      # HDD root
# or uRamdisk-recovery-ds115j / uRamdisk-ds115j for BusyBox recovery
bootm 0x01000000 0x02000000
```

Only serve the repository's `boot/` files. Do not boot an old `uImage-nodtb`
(no appended DTB).

## Laptop services

| Port | Service | Start from repository root |
|---|---|---|
| UDP **69** | macOS `tftpd` / Linux `tftpd-hpa` | `scripts/serve-tftp.sh` |
| TCP **45151** | SPI dump receiver | `python3 scripts/spi-recv-daemon.py` |
| TCP **45152** | rootfs HTTP | reconstruct first, then `python3 -m http.server 45152 --bind 0.0.0.0 --directory "$PWD"` |

No DHCP/PXE/NFS server is part of the repository setup.

## Historical helper

The former Raspberry Pi at `192.168.68.250` was used during bring-up. It is
optional and may be deleted. No installation, recovery, artifact, or script in
this repository requires it.

## Disk identifiers (do not reformat)

```text
sda1  64G   ext4  LABEL=rootfs  UUID=fc9ea304-14d5-4494-a117-7dfda838e18b  /
sda2  128M  ext2  LABEL=boot    UUID=eec9c4e3-7c83-40b6-af29-e28c4f228baa  (U-Boot source; not mounted in Linux by default)
~1.75 TiB unallocated
```

Physical sector size 4096; both partitions currently start off a 4 KiB boundary (`sda1` start 63).

## Live NAS listeners (2026-09-15 19:50 UTC)

Only **sshd :22** (IPv4 and IPv6). No Samba/NFS yet.

## Password handling

- NAS root password **`ds115j`** is the working credential.
- Do not print the LAN password in public tickets.
