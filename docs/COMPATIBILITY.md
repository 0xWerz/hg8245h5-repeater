# Compatibility

## Verified profile

- Model: Huawei EchoLife HG8245H5
- Firmware: `V500R021C10SPC200B140`
- Architecture: 32-bit ARM EABI
- LAN: `br0`, `192.168.100.1/24`
- Client AP: `vap0`
- Uplink station: `vap8`
- Persistent storage: `/mnt/jffs2`

The installer checks capabilities instead of trusting a model string. It
requires both VAPs, the HiSilicon private wireless control path, stock hostapd,
iptables, writable JFFS2 storage, and the audit-plugin boot hook.

## Adding a device

Run `doctor.sh` and open an issue containing only its redacted output. Never
include a configuration export, password, serial number, or full MAC address.
A new profile needs a successful cold boot, association, DHCP, DNS, HTTPS, and
uninstall/recovery test before it can be marked supported.

Similar model names are not evidence of compatibility. Huawei ONTs from the
same product family can use different SoCs, wireless drivers, interface names,
and boot mechanisms.
