# Architecture

```text
upstream AP
    |
    | 2.4 GHz station + DHCP
    v
  vap8 ---- NAT / forwarding ---- br0 ---- vap0 ---- clients
                                      |
                                      +---- setup UI :8080
```

The service keeps both virtual interfaces on the upstream channel. It clears a
Huawei WAN-policy mark on LAN packets before route lookup, forwards them through
`vap8`, and masquerades the LAN subnet. A watchdog recreates the uplink, DHCP
lease, firewall chains, output AP, and web server when necessary.

All project firewall objects use the `HG5R_` prefix. Shared vendor files are
backed up once and restored by the uninstaller.
