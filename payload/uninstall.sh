#!/bin/sh

set -u
PATH=/bin:/sbin:/usr/bin:/usr/sbin
PROJECT_DIR=/mnt/jffs2/Install_gram/hg8245h5-repeater
WEB_DIR=/mnt/jffs2/hg8245h5-repeater-web
BACKUP_DIR=/mnt/jffs2/Install_gram/hg8245h5-repeater-backup
FEATURE_FILE=/mnt/jffs2/hw_hardinfo_feature
CONTROL_HOOK=/mnt/jffs2/Install_gram/control_audit.sh

[ "$(id -u)" = 0 ] || { echo 'uninstall: root shell required' >&2; exit 1; }

if [ -s /var/run/hg5r-service.pid ]; then
    kill "$(cat /var/run/hg5r-service.pid)" 2>/dev/null || true
fi
if [ -s /var/run/hg5r-dhcp.pid ]; then
    kill "$(cat /var/run/hg5r-dhcp.pid)" 2>/dev/null || true
fi
if [ -x "$PROJECT_DIR/wpa_cli" ]; then
    "$PROJECT_DIR/wpa_cli" -p /var/run/wpa_supplicant -i vap8 terminate >/dev/null 2>&1 || true
fi
killall wpa_supplicant.hg5r 2>/dev/null || true
ps ww | grep '[h]ostapd' | grep "$PROJECT_DIR/hostapd-repeater.conf" | awk '{print $1}' | while read -r pid; do kill "$pid" 2>/dev/null || true; done
ps ww | grep '[b]usybox-repeater httpd' | grep ':8080' | awk '{print $1}' | while read -r pid; do kill "$pid" 2>/dev/null || true; done

while iptables -t mangle -D PREROUTING -j HG5R_MARK 2>/dev/null; do :; done
iptables -t mangle -F HG5R_MARK 2>/dev/null || true
iptables -t mangle -X HG5R_MARK 2>/dev/null || true
while iptables -t nat -D POSTROUTING -j HG5R_NAT 2>/dev/null; do :; done
iptables -t nat -F HG5R_NAT 2>/dev/null || true
iptables -t nat -X HG5R_NAT 2>/dev/null || true
while iptables -D FORWARD -j HG5R_FWD 2>/dev/null; do :; done
iptables -F HG5R_FWD 2>/dev/null || true
iptables -X HG5R_FWD 2>/dev/null || true
while iptables -t nat -D PREROUTING -j HG5R_DNS 2>/dev/null; do :; done
iptables -t nat -F HG5R_DNS 2>/dev/null || true
iptables -t nat -X HG5R_DNS 2>/dev/null || true

if [ -e "$BACKUP_DIR/hw_hardinfo_feature.original" ]; then
    cp -p "$BACKUP_DIR/hw_hardinfo_feature.original" "$FEATURE_FILE"
fi
if [ -e "$BACKUP_DIR/control_audit.sh.original" ]; then
    cp -p "$BACKUP_DIR/control_audit.sh.original" "$CONTROL_HOOK"
elif [ -e "$BACKUP_DIR/control_audit.sh.absent" ]; then
    rm -f "$CONTROL_HOOK"
fi
sync

if [ -x "$PROJECT_DIR/busybox-repeater" ]; then
    "$PROJECT_DIR/busybox-repeater" rm -rf "$WEB_DIR"
    "$PROJECT_DIR/busybox-repeater" rm -rf "$PROJECT_DIR"
else
    echo "warning: remove $WEB_DIR and $PROJECT_DIR manually" >&2
fi

echo 'Uninstalled. Reboot now to restore the stock access point.'
