# Build and artifact notes

## Debian root filesystem

The exact command and mirror used to create the old checked-in rootfs were not
recorded. This repository now provides a supported build instead of storing
that large archive.

On a Debian or Ubuntu Linux host (or a Linux VM with the repository shared),
install the build tools and run:

```bash
sudo apt update
sudo apt install mmdebstrap kmod openssl openssh-client curl
cd /path/to/ds115j
sudo scripts/reconstruct-rootfs.sh
```

The scripts build a minimal Debian trixie `armhf` filesystem from
`deb.debian.org`, add the project configuration, install the matching kernel
modules, generate fresh SSH host keys, and prompt for a unique root password.
The generated rootfs archive and install kit are ignored by Git. The install
guide serves these generated files to the NAS over a trusted local network.
Network settings are copied from `config/`; review them for the target NAS
before building.

`MIRROR` can be set when running the builder to use another Debian mirror.
`ROOTFS_TARGET` can select a different output directory:

```bash
sudo MIRROR=https://deb.debian.org/debian \
  ROOTFS_TARGET=/path/to/build/rootfs \
  scripts/reconstruct-rootfs.sh
```

The old archive is still present in earlier Git commits and in upstream
history. Removing it from the current tree does not erase it from those
histories.

## Kernel image

The checked-in `uImage` is **not a raw Synology SPI kernel dump**. The project
history identifies its base as Debian's `linux-image-6.12.107+deb13-armmp`
binary package, version `6.12.107-1`, architecture `armhf`. The U-Boot image
wraps that Debian kernel image with the project device tree appended. The
device-tree source and compiled DTB are in [`dts/`](../dts/).

The package is available from the
[Debian Snapshot record for Linux 6.12.107-1](https://snapshot.debian.org/package/linux/6.12.107-1/).
The rootfs builder downloads the exact package by its Debian Snapshot content
hash to install the matching module tree.

The kernel can be repackaged from that Debian binary package and the checked-in
DTB. On Linux, with `curl`, `dpkg-deb`, `sha1sum`, and `u-boot-tools`
installed:

```bash
set -eu
KVER=6.12.107+deb13-armmp
PACKAGE_HASH=c71eb4571b069d8eb493b27614e109f029623f10
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

curl --fail --location \
  "https://snapshot.debian.org/file/$PACKAGE_HASH" \
  --output "$WORK/linux-image-armmp.deb"
echo "$PACKAGE_HASH  $WORK/linux-image-armmp.deb" | sha1sum -c -
test "$(dpkg-deb -f "$WORK/linux-image-armmp.deb" Version)" = 6.12.107-1
dpkg-deb --extract "$WORK/linux-image-armmp.deb" "$WORK/kernel"

cat "$WORK/kernel/boot/vmlinuz-$KVER" dts/ds115j.dtb \
  > "$WORK/zImage-with-dtb"
mkimage -A arm -O linux -T kernel -C none \
  -a 0x00008000 -e 0x00008000 \
  -n "Debian 6.12.107 DS115j USB" \
  -d "$WORK/zImage-with-dtb" "$WORK/uImage-ds115j"
dumpimage -l "$WORK/uImage-ds115j"
```

This repackages Debian's kernel; it does not compile the Linux kernel. Editing
the DTS requires the matching Debian kernel source tree for its included board
files and bindings. The current checked-in DTB avoids that dependency for
repackaging.

The recipe has not yet been validated end-to-end in this repository. Do not
replace the checked-in image with an unverified build: the kernel, appended
DTB, ramdisk, and `qnap_poweroff_ds115j` module must remain ABI-compatible.
Check the image contents and hashes, then test it from UART/TFTP before
installing it on the boot partition.

## Ramdisks

The HDD and recovery ramdisk binaries are checked in because their original
unpacked initramfs trees are not in the repository. The legacy
[`rebuild-hdd-ramdisk.sh`](../scripts/rebuild-hdd-ramdisk.sh) and
[`rebuild-ramdisk.sh`](../scripts/rebuild-ramdisk.sh) expect those external
trees under `/root/ds115j/initramfs-hdd` and `/root/ds115j/initramfs`.
Consequently, these scripts are not standalone rebuild instructions. Keep the
known-good ramdisks until their source trees and a tested recipe are available.

The files under [`firmware/spi/`](../firmware/spi/) are separate vendor-firmware
forensics artifacts. They are not the source of the Debian kernel image.
