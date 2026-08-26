#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
if [ -r "$SCRIPT_DIR/profile.env" ]; then
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/profile.env"
else
    # shellcheck disable=SC1091
    . /mnt/jffs2/Install_gram/hg8245h5-repeater/profile.env
fi

failures=0

pass() { printf '[ok]   %s\n' "$1"; }
fail() { printf '[fail] %s\n' "$1"; failures=$((failures + 1)); }

check_path() {
    if [ "$1" = d ]; then
        if [ -d "$2" ]; then pass "$3"; else fail "$3"; fi
    elif [ "$1" = w ]; then
        if [ -w "$2" ]; then pass "$3"; else fail "$3"; fi
    else
        if [ -e "$2" ]; then pass "$3"; else fail "$3"; fi
    fi
}

printf 'HG8245H5 repeater doctor\n'
printf 'kernel: %s %s\n' "$(uname -s)" "$(uname -r)"

if [ "$(id -u)" = 0 ]; then pass 'running as root'; else fail 'root shell required'; fi
case "$(uname -m)" in arm*|ARM*) pass '32-bit ARM runtime' ;; *) fail 'expected ARM runtime' ;; esac

check_path d "/sys/class/net/$LAN_IF" "LAN interface $LAN_IF"
check_path d "/sys/class/net/$AP_IF" "access-point interface $AP_IF"
check_path d "/sys/class/net/$STA_IF" "station interface $STA_IF"
check_path w /sys/hisys/hipriv 'HiSilicon private wireless control'
check_path w /mnt/jffs2 'writable persistent storage'
check_path f /bin/hostapd 'stock hostapd'
check_path f /bin/audit 'audit boot dispatcher'
check_path f /mnt/jffs2/hw_hardinfo_feature 'feature database'

for command in ifconfig iwconfig iwpriv iptables route start-stop-daemon; do
    if command -v "$command" >/dev/null 2>&1; then pass "command $command"; else fail "missing command $command"; fi
done

if grep -q '^cfg_wifi:' /etc/passwd 2>/dev/null; then pass 'cfg_wifi service account'; else fail 'missing cfg_wifi service account'; fi

if [ -d "$SCRIPT_DIR/files" ]; then
    BIN_DIR=$SCRIPT_DIR/files
else
    BIN_DIR=$PROJECT_DIR
fi
for binary in busybox-repeater wpa_supplicant.hg5r wpa_cli; do
    if [ -x "$BIN_DIR/$binary" ]; then pass "helper $binary"; else fail "missing helper $binary"; fi
done

if [ -d "$PROJECT_DIR" ]; then
    printf '\nInstalled service\n'
    if [ -s /var/run/hg5r-service.pid ] && kill -0 "$(cat /var/run/hg5r-service.pid)" 2>/dev/null; then
        pass 'watchdog running'
    else
        if [ "${1:-}" = --health ]; then fail 'watchdog not running'; else printf '[info] watchdog not running\n'; fi
    fi
    # The verified BusyBox runtime has no pgrep.
    # shellcheck disable=SC2009
    if ps ww | grep '[h]ostapd' | grep -q "$PROJECT_DIR/hostapd-repeater.conf"; then
        pass 'output AP running'
    elif [ "${1:-}" = --health ]; then
        fail 'output AP not running'
    else
        printf '[info] output AP not running\n'
    fi
    state=$("$PROJECT_DIR/wpa_cli" -p /var/run/wpa_supplicant -i "$STA_IF" status 2>/dev/null | sed -n 's/^wpa_state=//p' | head -1)
    [ "$state" = COMPLETED ] && pass 'upstream associated' || printf '[info] upstream state: %s\n' "${state:-not configured}"
    if netstat -lnt 2>/dev/null | grep -q ':8080 '; then
        pass 'setup UI listening'
    elif [ "${1:-}" = --health ]; then
        fail 'setup UI not listening'
    else
        printf '[info] setup UI not listening\n'
    fi
fi

if [ "$failures" -ne 0 ]; then
    printf '\nResult: unsupported or unhealthy (%s failed checks)\n' "$failures"
    exit 1
fi
printf '\nResult: compatible\n'
