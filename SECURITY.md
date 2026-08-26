# Security

## Reporting

Please report security problems privately through GitHub's security-advisory
feature. Do not include router passwords, Wi-Fi credentials, configuration
exports, serial numbers, or MAC addresses in public issues.

## Scope

The project requires an existing root shell and intentionally does not publish
the firmware-specific privilege-escalation chain used during initial research.
The setup UI is available only on the ONT's LAN address, uses plain HTTP, and
should be treated as an appliance-local administration surface.

Use this software only on equipment you own or have explicit authorization to
modify.
