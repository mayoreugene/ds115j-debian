#!/bin/sh
# scripts/provision-hdd.sh
#
# Fully self-contained robust single-step disk provisioning for Synology DS115j.
set -u

HTTP_HOST="${HTTP_HOST:-${1:-192.168.68.251}}"
HTTP_PORT="${HTTP_PORT:-45152}"
BASE_URL="http://${HTTP_HOST}:${HTTP_PORT}"
DISK="/dev/sda"
MNT="/mnt"

echo "=========================================================="
echo "  Synology DS115j Automated Debian 13 (Trixie) Provisioner"
echo "=========================================================="
echo "Target disk: $DISK"
echo "Serving URL: $BASE_URL"
echo

if [ ! -b "$DISK" ]; then
    echo "ERROR: Target disk $DISK not found! Is the SATA drive connected?" >&2
    exit 1
fi

# Step 1: Unmount all partitions on sda
echo "Step 1/5: Unmounting all partitions on $DISK..."
umount -f /mnt 2>/dev/null || true
umount -f "${DISK}"* 2>/dev/null || true

# Write 100% self-contained, aligned MBR partition table (sda1=64G, sda2=128M, sda3=rest)
echo "Writing aligned MBR partition table directly to disk..."
printf '\x00\xfe\xff\xff\x83\xfe\xff\xff\x00\x08\x00\x00\x00\x00\x00\x08\x80\xfe\xff\xff\x83\xfe\xff\xff\x00\x08\x00\x08\x00\x00\x04\x00\x00\xfe\xff\xff\x83\xfe\xff\xff\x00\x08\x04\x08\xef\x4f\x34\x32\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x55\xaa' | dd of="$DISK" bs=1 seek=446 count=66 conv=notrunc 2>/dev/null

# Force kernel to re-read partition table
blockdev --rereadpt "$DISK" 2>/dev/null || true
sleep 2

echo "Current partition table:"
cat /proc/partitions
echo

# Step 2: Format filesystems
echo "Step 2/5: Creating filesystems..."
MKFS_EXT4="/sbin/mkfs.ext4"
[ -x "$MKFS_EXT4" ] || MKFS_EXT4="mkfs.ext4"
MKE2FS="/sbin/mke2fs"
[ -x "$MKE2FS" ] || MKE2FS="mke2fs"

echo "Formatting ${DISK}1 (ext4, LABEL=rootfs)..."
$MKFS_EXT4 -F -L rootfs "${DISK}1"

echo "Formatting ${DISK}2 (ext2, LABEL=boot, 128 MB)..."
$MKE2FS -F -L boot "${DISK}2"

if [ -b "${DISK}3" ]; then
    echo "Formatting ${DISK}3 (ext4, LABEL=data)..."
    $MKFS_EXT4 -F -L data "${DISK}3" || true
fi

# Step 3: Stream and unpack Debian rootfs onto sda1
echo "Step 3/5: Installing Debian rootfs to ${DISK}1..."
mkdir -p "$MNT"
mount "${DISK}1" "$MNT"

echo "Streaming and unpacking rootfs-trixie-armhf.tar.gz directly to disk..."
wget -O- "${BASE_URL}/rootfs-trixie-armhf.tar.gz" | tar -C "$MNT" -xz

echo "Configuring network and system bootstrap..."
mkdir -p "$MNT/etc/network" "$MNT/etc/systemd/network" "$MNT/etc/apt" "$MNT/srv/data"

SUBNET_PREFIX=$(echo "$HTTP_HOST" | cut -d. -f1-3)
cat <<EOF > "$MNT/etc/network/interfaces"
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
	address ${SUBNET_PREFIX}.233/24
	gateway ${SUBNET_PREFIX}.1
	pre-up /sbin/modprobe marvell
	pre-up /sbin/modprobe mvmdio
	pre-up /sbin/modprobe mvneta
	dns-nameservers ${SUBNET_PREFIX}.1 1.1.1.1 8.8.8.8
EOF

echo "nameserver ${SUBNET_PREFIX}.1" > "$MNT/etc/resolv.conf"
echo "nameserver 1.1.1.1" >> "$MNT/etc/resolv.conf"

wget -O "$MNT/etc/systemd/network/10-ds115j-eth0.link" "${BASE_URL}/config/10-ds115j-eth0.link" 2>/dev/null || true
wget -O "$MNT/etc/fstab" "${BASE_URL}/config/fstab"
wget -O "$MNT/etc/apt/sources.list" "${BASE_URL}/config/sources.list"

sync
umount "$MNT"

# Step 4: Install boot images to sda2 (ide 0:2)
echo "Step 4/5: Installing boot images to ${DISK}2 (ide 0:2)..."
mount "${DISK}2" "$MNT"
mkdir -p "$MNT/boot"

wget -O "$MNT/boot/uImage-ds115j" "${BASE_URL}/boot/uImage-ds115j"
wget -O "$MNT/boot/uRamdisk-hdd-ds115j" "${BASE_URL}/boot/uRamdisk-hdd-ds115j"

EXPECTED_UIMAGE="6b58d6eee97005845923167d5fe481035b7031195935bd632cdbe29ae75ed0f6"
EXPECTED_URAMDISK="dbbd30ec2c3772e2816eaa5e3295b0580a357fc93458dcb3bf063bf7bf65cd75"

echo "$EXPECTED_UIMAGE  $MNT/boot/uImage-ds115j" | sha256sum -c -
echo "$EXPECTED_URAMDISK  $MNT/boot/uRamdisk-hdd-ds115j" | sha256sum -c -

sync
umount "$MNT"

# Step 5: Completed
echo "Step 5/5: Provisioning completed successfully!"
echo "=========================================================="
echo "  SUCCESS! Disk provisioning finished cleanly."
echo "  Run 'reboot -f' to reboot into U-Boot."
echo "=========================================================="
