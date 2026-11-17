#!/bin/sh
# Build the rootfs from Debian packages and package it for installation.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=${1:-"$ROOT/rootfs-trixie-armhf.tar.gz"}
KIT="$ROOT/ds115j-install-kit.tar.gz"
TARGET=${ROOTFS_TARGET:-"$ROOT/rootfs-build"}

TARGET="$TARGET" "$ROOT/scripts/bootstrap-rootfs.sh"
tar --numeric-owner --xattrs --acls -C "$TARGET" -czf "$OUT" .
if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL=$(sha256sum "$OUT" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    ACTUAL=$(shasum -a 256 "$OUT" | awk '{print $1}')
else
    echo "Neither sha256sum nor shasum found" >&2
    exit 1
fi

echo "Built rootfs archive: $OUT"
echo "SHA-256: $ACTUAL"

# Small, self-contained second-stage kit served beside the rootfs. Keeping it
# local avoids depending on GitHub from the NAS and guarantees config/script
# versions match this checkout.
tar -C "$ROOT" -czf "$KIT" README.md config modules scripts
echo "Built userspace kit: $KIT"
