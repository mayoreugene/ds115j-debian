#!/bin/bash
# Build a Debian trixie armhf rootfs from Debian mirrors on a Linux laptop.
# Does not talk to the NAS, does not flash, does not saveenv.
#
# Chrootless mode does not execute armhf binaries on the host.
# Remaining dpkg --configure -a happens on first boot on the NAS (4 KiB).
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TARGET=${TARGET:-$ROOT/rootfs-build}
export TARGET
DIST=trixie
ARCH=armhf
MIRROR=${MIRROR:-http://deb.debian.org/debian}
LOG=$ROOT/rootfs-bootstrap.log
INCLUDE=systemd,systemd-sysv,openssh-server,sudo,vim-tiny,usbutils,mtd-utils,ifupdown,ca-certificates,kmod,udev,iproute2,iputils-ping,fdisk,e2fsprogs,wget
KVER=6.12.107+deb13-armmp
KERNEL_DEB_SHA1=c71eb4571b069d8eb493b27614e109f029623f10
KERNEL_DEB_URL=https://snapshot.debian.org/file/$KERNEL_DEB_SHA1

exec > >(tee -a "$LOG") 2>&1
echo "=== $(date -Is) bootstrap-rootfs start ==="

install_kernel_modules() {
    modules=$TARGET/usr/lib/modules/$KVER
    if [ -f "$modules/modules.dep" ]; then
        echo "Matching kernel modules already present."
        return
    fi
    if [ -d "$modules" ]; then
        if ! command -v depmod >/dev/null; then
            echo "Need depmod on the Linux build host." >&2
            exit 1
        fi
        depmod -b "$TARGET" "$KVER"
        if [ -f "$modules/modules.dep" ]; then
            echo "Generated module dependency indexes."
            return
        fi
    fi

    for tool in dpkg-deb depmod sha1sum; do
        if ! command -v "$tool" >/dev/null; then
            echo "Need $tool on the Linux build host." >&2
            exit 1
        fi
    done

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    deb=$work/linux-image-armmp.deb
    unpacked=$work/unpacked
    mkdir -p "$unpacked"

    if command -v curl >/dev/null; then
        curl --fail --location --output "$deb" "$KERNEL_DEB_URL"
    elif command -v wget >/dev/null; then
        wget -O "$deb" "$KERNEL_DEB_URL"
    else
        echo "Need curl or wget to download the matching Debian kernel package." >&2
        exit 1
    fi
    echo "$KERNEL_DEB_SHA1  $deb" | sha1sum -c -

    package=$(dpkg-deb -f "$deb" Package)
    version=$(dpkg-deb -f "$deb" Version)
    architecture=$(dpkg-deb -f "$deb" Architecture)
    if [ "$package" != linux-image-6.12.107+deb13-armmp ] ||
        [ "$version" != 6.12.107-1 ] || [ "$architecture" != armhf ]; then
        echo "Unexpected Debian kernel package metadata." >&2
        exit 1
    fi

    dpkg-deb --extract "$deb" "$unpacked"
    source_modules=$unpacked/usr/lib/modules/$KVER
    if [ ! -d "$source_modules" ]; then
        source_modules=$unpacked/lib/modules/$KVER
    fi
    if [ ! -d "$source_modules" ] ||
        ! find "$source_modules" -type f \( -name '*.ko' -o -name '*.ko.xz' \) -print -quit | grep -q .; then
        echo "Kernel package is missing the expected module tree: $KVER" >&2
        exit 1
    fi

    install -d "$TARGET/usr/lib/modules"
    rm -rf "$modules"
    cp -a "$source_modules" "$TARGET/usr/lib/modules/"
    depmod -b "$TARGET" "$KVER"
    rm -rf "$work"
    trap - EXIT
}

ready() {
    [ -e "$TARGET/sbin/init" ] && [ -d "$TARGET/etc/apt" ] && [ ! -d "$TARGET/debootstrap" ] && [ -e "$TARGET/usr/bin/dpkg" ]
}

if ready; then
    echo "Rootfs already present at $TARGET — skipping unpack."
    install_kernel_modules
    "$ROOT/scripts/configure-rootfs.sh"
    exit 0
fi

if [ -d "$TARGET" ] && [ -d "$TARGET/debootstrap" ]; then
    BAK=$ROOT/rootfs.failed-qemu-$(date +%Y%m%d-%H%M%S)
    echo "Moving incomplete debootstrap tree aside -> $BAK"
    mv "$TARGET" "$BAK"
fi

mkdir -p "$TARGET"

if ! command -v mmdebstrap >/dev/null; then
    echo "Need mmdebstrap (apt install mmdebstrap)." >&2
    exit 1
fi

echo "=== mmdebstrap --mode=chrootless $DIST $ARCH ==="
mmdebstrap --verbose --skip=check/empty --skip=check/chrootless \
    --arch="$ARCH" --variant=minbase --mode=chrootless \
    --include="$INCLUDE" \
    "$DIST" "$TARGET" "$MIRROR"

install_kernel_modules

# First-boot hook: finish package configuration on the NAS (4K pages).
install -d "$TARGET/etc/systemd/system/multi-user.target.wants" \
           "$TARGET/usr/local/libexec"
cat > "$TARGET/usr/local/libexec/ds115j-second-stage.sh" <<'EOF'
#!/bin/sh
# Runs once on the NAS. Safe no-op after /etc/ds115j-second-stage-done exists.
set -e
[ -e /etc/ds115j-second-stage-done ] && exit 0
export DEBIAN_FRONTEND=noninteractive
[ ! -x /usr/bin/dpkg ] || dpkg --configure -a
[ ! -x /usr/bin/apt-get ] || apt-get -y -f install
date -u > /etc/ds115j-second-stage-done
systemctl disable ds115j-second-stage.service 2>/dev/null || true
EOF
chmod 0755 "$TARGET/usr/local/libexec/ds115j-second-stage.sh"

cat > "$TARGET/etc/systemd/system/ds115j-second-stage.service" <<'EOF'
[Unit]
Description=Finish Debian package configuration on DS115j
Wants=network-online.target
After=local-fs.target network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/libexec/ds115j-second-stage.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
ln -sfn /etc/systemd/system/ds115j-second-stage.service \
    "$TARGET/etc/systemd/system/multi-user.target.wants/ds115j-second-stage.service"

"$ROOT/scripts/configure-rootfs.sh"

echo "=== $(date -Is) bootstrap-rootfs done ==="
du -sh "$TARGET"
echo "Rootfs built at $TARGET. See docs/install-uart.md."
