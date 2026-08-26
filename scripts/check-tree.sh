#!/bin/sh

set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

find payload scripts -type f \( -name '*.sh' -o -name '*.script' -o -name '*.cgi' \) -print | while read -r script; do
    sh -n "$script"
done

if find . -path ./.git -prune -o -path ./build -prune -o -path ./vendor -prune -o -type f -exec file {} \; | grep -q 'ELF .* executable'; then
    echo 'tracked source tree contains an ELF binary' >&2
    exit 1
fi

if grep -R -n -E --exclude-dir=.git --exclude=check-tree.sh 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' .; then
    echo 'private key material found' >&2
    exit 1
fi

for generated in wpa-repeater.conf hostapd-repeater.conf hostapd-repeater.psk; do
    if find . -path ./build -prune -o -path ./.git -prune -o -path ./payload/templates -prune -o -name "$generated" -print | grep -q .; then
        echo "generated secret file is present: $generated" >&2
        exit 1
    fi
done

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git diff --check
fi

echo 'tree checks passed'
