#!/bin/sh

set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
IMAGE=hg8245h5-repeater-toolchain:1

command -v docker >/dev/null 2>&1 || {
    echo 'Docker is required to build the ARM helpers.' >&2
    exit 1
}

mkdir -p "$ROOT/vendor/bin" "$ROOT/vendor/licenses"
docker build --platform linux/amd64 -t "$IMAGE" -f "$ROOT/third_party/Dockerfile" "$ROOT"
docker run --rm --platform linux/amd64 -v "$ROOT/vendor:/out" "$IMAGE"

for binary in busybox-repeater wpa_supplicant.hg5r wpa_cli; do
    test -x "$ROOT/vendor/bin/$binary"
    file "$ROOT/vendor/bin/$binary" | grep -q 'ELF 32-bit LSB.*ARM'
    file "$ROOT/vendor/bin/$binary" | grep -q 'statically linked'
done
echo 'ARM helpers built under vendor/bin/'
