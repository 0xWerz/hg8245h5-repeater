# HG8245H5 Repeater

Turn a spare Huawei EchoLife HG8245H5 into a self-contained 2.4 GHz Wi-Fi
repeater, without replacing its firmware.

The service uses the stock access-point interface (`vap0`) for clients and a
second vendor interface (`vap8`) as the wireless uplink. It adds DHCP uplink,
NAT, DNS forwarding, a watchdog, and a small setup page at
`http://192.168.100.1:8080`.

## Support status

| Device | Firmware | Status |
| --- | --- | --- |
| Huawei HG8245H5 | `V500R021C10SPC200B140` | Verified end to end |
| Other HG8245H5 R21 builds | Unknown | Preflight only; reports welcome |
| Other Huawei ONTs | Unsupported | Do not install |

This is not OpenWrt and it does not modify the signed firmware image. The
installer deliberately refuses devices that lack the exact runtime features
used by the verified unit. See [compatibility](docs/COMPATIBILITY.md).

## Requirements

- A device you own or are authorized to modify.
- An existing root shell on the ONT. The public installer does not include the
  firmware-specific privilege-escalation path used during research.
- Docker for reproducibly building the two ARM helper programs.
- Python 3 on the preparation computer.

## Build and install

```sh
make third-party
make package
```

`make package` asks for the output SSID and password without storing either in
Git. It creates `dist/hg8245h5-repeater.tar.gz`.

Transfer that archive to `/tmp` on the ONT using your existing root-access
method, then run on the ONT:

```sh
mkdir /tmp/hg8245h5-repeater
cd /tmp/hg8245h5-repeater
tar -xzf ../hg8245h5-repeater.tar.gz
./doctor.sh
./install.sh
reboot
```

After boot, connect to the output SSID and open
`http://192.168.100.1:8080`. Scan, select the upstream Wi-Fi network, enter its
password, and save. The upstream password remains on the router and is never
part of the source tree.

## Operations

```sh
./doctor.sh       # non-mutating compatibility and health report
./uninstall.sh    # restore backed-up boot files and remove the service
```

The installer is idempotent, backs up each shared vendor file before changing
it, verifies checksums, and installs through a staging directory. Recovery is
documented in [RECOVERY.md](docs/RECOVERY.md).

## Limits

- 2.4 GHz only.
- NAT repeater, not a transparent wireless bridge.
- A single radio receives and retransmits each packet, so maximum throughput is
  lower than a wired access point.
- Confirmed on one hardware/firmware combination. Compatibility is based on
  runtime probes, not similar-looking model names.

## License

Project code is GPL-2.0-only. BusyBox and wpa_supplicant retain their upstream
licenses and are built from pinned, verified source archives. See
[THIRD_PARTY.md](THIRD_PARTY.md).
