# Third-party software

The Git repository does not contain third-party binaries.
`scripts/build-third-party.sh` builds the following pinned releases in an
isolated Linux container:

| Component | Version | License | Source SHA-256 |
| --- | --- | --- | --- |
| BusyBox | 1.36.1 | GPL-2.0-only | `b8cc24c9574d809e7279c3be349795c5d5ceb6fdf19ca709f80cde50e47de314` |
| wpa_supplicant / wpa_cli | 2.10 | BSD-3-Clause | `20df7ae5154b3830355f8ab4269123a87affdea59fe74fe9292a91d0d7e17b2f` |

The BusyBox archive comes from Buildroot's source mirror and is byte-verified
against the published release checksum. The wpa_supplicant archive comes from
the upstream w1.fi release server. Their license files are copied into
`vendor/licenses/` by the build. Generated binaries under `vendor/bin/` are
ignored by Git.

Huawei's stock `hostapd`, kernel, wireless driver, and userspace remain on the
device. No Huawei binary or firmware image is redistributed by this project.
