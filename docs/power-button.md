# Front power button

> **Verification record:** the complete button-to-power-off path was tested on
> the device on 2026-09-21. This is a historical result, not a live health
> check.

## How it works

The front button signals the PIC16LF1828 over UART1 (`/dev/ttyS1`, 9600 8N1).
After initialization, a press-and-hold produces byte `0x30`. The
`syno-powerbtn` service listens read-only for that byte and requests a clean
system shutdown. The matching `qnap_poweroff_ds115j` module then cuts power.

The PIC needs the newline-terminated initialization bytes `4` and `9` after
boot. The `syno-powerbtn-arm` unit sends these; do not use UART1 as a console
or send arbitrary bytes to it.

## Configuration and installed files

The repository configuration sets `TRIGGER_BYTES="30"` so the front button
can request shutdown. Check `/etc/syno-powerbtn.conf` on the device before
relying on the behavior.

| File | Purpose |
|---|---|
| `scripts/syno-powerbtn.sh` | Read-only PIC event listener |
| `scripts/syno-powerbtn.conf` | Trigger-byte setting |
| `scripts/syno-powerbtn.service` | Listener service |
| `scripts/syno-powerbtn-arm.sh` | Sends the required initialization bytes |
| `scripts/syno-powerbtn-arm.service` | Runs initialization at boot |

## Check operation

Replace `<NAS_IP>` with the address configured for your NAS:

```bash
ssh root@<NAS_IP>
systemctl is-active syno-powerbtn syno-powerbtn-arm
grep '^TRIGGER_BYTES=' /etc/syno-powerbtn.conf
journalctl -u syno-powerbtn --no-pager -n 20
```

The recorded live test observed `0x30` on button press, followed by a clean
shutdown. The PIC retained its armed state across a normal power-off; the boot
unit initializes it again defensively.

## Safety

- The listener reads UART1; it does not write event replies to the PIC.
- Do not manually send `'1'` (power-off) or `'C'` (reset). The kernel module
  handles power-off.
- Keep UART0 available during troubleshooting. Never write U-Boot environment
  data or SPI as part of routine button diagnosis.

The protocol investigation and vendor firmware evidence are recorded in
[`firmware/spi/README`](../firmware/spi/README).
