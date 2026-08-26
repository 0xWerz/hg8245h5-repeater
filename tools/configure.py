#!/usr/bin/env python3
"""Create a credential-bearing installation bundle outside the Git tree."""

from __future__ import annotations

import argparse
import getpass
import hashlib
import os
import shutil
import stat
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / "build" / "stage"

BINARIES = {
    "busybox-repeater": "busybox-repeater",
    "wpa_supplicant.hg5r": "wpa_supplicant.hg5r",
    "wpa_cli": "wpa_cli",
}

PROJECT_FILES = (
    "repeater_bootstrap.sh",
    "apply.sh",
    "audit-hook.sh",
    "audit-feature-line.cfg",
    "udhcpc.script",
)


def validate_ssid(value: str) -> str:
    encoded = value.encode("utf-8")
    if not 1 <= len(encoded) <= 32:
        raise ValueError("output SSID must be 1–32 UTF-8 bytes")
    if any(byte < 0x20 or byte == 0x7F for byte in encoded):
        raise ValueError("output SSID cannot contain control characters")
    if "\n" in value or "\r" in value:
        raise ValueError("output SSID must fit on one line")
    return value


def validate_psk(value: str) -> str:
    if not 8 <= len(value) <= 63:
        raise ValueError("output password must contain 8–63 characters")
    if any(ord(character) < 0x20 or ord(character) == 0x7F for character in value):
        raise ValueError("output password cannot contain control characters")
    return value


def derive_psk(ssid: str, passphrase: str) -> str:
    return hashlib.pbkdf2_hmac(
        "sha1", passphrase.encode(), ssid.encode(), 4096, 32
    ).hex()


def copy_executable(source: Path, destination: Path) -> None:
    shutil.copy2(source, destination)
    destination.chmod(destination.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_stage(ssid: str, passphrase: str) -> None:
    if STAGE.exists():
        shutil.rmtree(STAGE)
    files = STAGE / "files"
    web = STAGE / "web"
    files.mkdir(parents=True)

    payload = ROOT / "payload"
    profile = ROOT / "profiles" / "hg8245h5-r21.env"
    shutil.copy2(profile, STAGE / "profile.env")
    for name in ("install.sh", "uninstall.sh", "doctor.sh"):
        copy_executable(payload / name, STAGE / name)
    for name in PROJECT_FILES:
        destination = files / name
        shutil.copy2(payload / name, destination)
        if name.endswith(".sh") or name.endswith(".script"):
            destination.chmod(0o755)

    for source_name, destination_name in BINARIES.items():
        source = ROOT / "vendor" / "bin" / source_name
        if not source.is_file():
            raise FileNotFoundError(
                f"missing {source}; run `make third-party` first"
            )
        if source.read_bytes()[:4] != b"\x7fELF":
            raise ValueError(f"{source} is not an ELF executable")
        copy_executable(source, files / destination_name)

    shutil.copy2(payload / "templates" / "wpa-repeater.conf", files / "wpa-repeater.conf")
    shutil.copy2(payload / "templates" / "settings.env", files / "settings.env")

    template = (payload / "templates" / "hostapd-repeater.conf.in").read_text()
    output_uuid = uuid.uuid5(uuid.NAMESPACE_URL, f"hg8245h5-repeater:{ssid}")
    rendered = template.replace("@OUTPUT_SSID@", ssid).replace(
        "@OUTPUT_UUID@", str(output_uuid)
    )
    (files / "hostapd-repeater.conf").write_text(rendered)
    (files / "hostapd-repeater.psk").write_text(
        f"00:00:00:00:00:00 {derive_psk(ssid, passphrase)}\n"
    )
    (files / "hostapd-repeater.conf").chmod(0o640)
    (files / "hostapd-repeater.psk").chmod(0o640)
    (files / "wpa-repeater.conf").chmod(0o600)
    (files / "settings.env").chmod(0o600)

    shutil.copytree(payload / "web", web)
    for cgi in (web / "cgi-bin").glob("*.cgi"):
        cgi.chmod(0o755)

    entries = []
    for path in sorted(item for item in STAGE.rglob("*") if item.is_file()):
        relative = path.relative_to(STAGE)
        entries.append(f"{sha256(path)}  {relative.as_posix()}")
    (STAGE / "manifest.sha256").write_text("\n".join(entries) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--ssid",
        default=os.environ.get("HG5R_OUTPUT_SSID", "HG8245H5-Repeater"),
        help="output SSID (default: HG8245H5-Repeater)",
    )
    args = parser.parse_args()

    try:
        ssid = validate_ssid(args.ssid)
        passphrase = os.environ.get("HG5R_OUTPUT_PSK") or getpass.getpass(
            "Output Wi-Fi password: "
        )
        validate_psk(passphrase)
        build_stage(ssid, passphrase)
    except (ValueError, FileNotFoundError) as error:
        parser.error(str(error))

    print(f"Prepared {STAGE}")
    print("The generated directory contains a Wi-Fi secret and is ignored by Git.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
