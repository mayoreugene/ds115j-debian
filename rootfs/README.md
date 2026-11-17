# Root filesystem

The generated Debian root filesystem is intentionally not stored in Git.
Build it on a Linux host with:

```bash
sudo scripts/reconstruct-rootfs.sh
```

This creates `rootfs-trixie-armhf.tar.gz` and
`ds115j-install-kit.tar.gz` in the repository root. Both are ignored by Git.
The build needs Linux, `mmdebstrap`, `dpkg-deb`, `depmod`, `sha1sum`, OpenSSL,
`ssh-keygen`, Python 3, GNU tar, and `curl` or `wget`. It downloads packages
from Debian and prompts for a unique initial root password.

See [build notes](../docs/build-artifacts.md) for details.
