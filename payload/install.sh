#!/bin/sh

set -eu
PATH=/bin:/sbin:/usr/bin:/usr/sbin
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/profile.env"

FILES=$SCRIPT_DIR/files
WEB_SOURCE=$SCRIPT_DIR/web
BACKUP_DIR=/mnt/jffs2/Install_gram/hg8245h5-repeater-backup
FEATURE_FILE=/mnt/jffs2/hw_hardinfo_feature
CONTROL_HOOK=/mnt/jffs2/Install_gram/control_audit.sh

die() { echo "install: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die 'root shell required'
[ -d "$FILES" ] || die 'package is incomplete: files directory missing'
[ -d "$WEB_SOURCE" ] || die 'package is incomplete: web directory missing'

"$SCRIPT_DIR/doctor.sh"
(cd "$SCRIPT_DIR" && "$FILES/busybox-repeater" sha256sum -c manifest.sha256)

if [ -s /var/run/hg5r-service.pid ]; then
    kill "$(cat /var/run/hg5r-service.pid)" 2>/dev/null || true
    sleep 2
fi

mkdir -p "$BACKUP_DIR"
if [ ! -e "$BACKUP_DIR/hw_hardinfo_feature.original" ]; then
    cp -p "$FEATURE_FILE" "$BACKUP_DIR/hw_hardinfo_feature.original"
fi
if [ ! -e "$BACKUP_DIR/control_audit.sh.original" ] && [ ! -e "$BACKUP_DIR/control_audit.sh.absent" ]; then
    if [ -e "$CONTROL_HOOK" ]; then
        cp -p "$CONTROL_HOOK" "$BACKUP_DIR/control_audit.sh.original"
    else
        : >"$BACKUP_DIR/control_audit.sh.absent"
    fi
fi

stage="$PROJECT_DIR.new.$$"
web_stage="$WEB_DIR.new.$$"
mkdir "$stage" "$web_stage"
cp -p "$FILES"/* "$stage"/
cp -p "$SCRIPT_DIR/profile.env" "$stage/profile.env"
cp -p "$SCRIPT_DIR/uninstall.sh" "$SCRIPT_DIR/doctor.sh" "$stage"/
cp -p "$WEB_SOURCE/index.html" "$web_stage"/
mkdir "$web_stage/cgi-bin"
cp -p "$WEB_SOURCE/cgi-bin"/*.cgi "$web_stage/cgi-bin"/

chmod 755 "$stage"/*.sh "$stage/busybox-repeater" "$stage/wpa_supplicant.hg5r" "$stage/wpa_cli"
chmod 755 "$web_stage/cgi-bin"/*.cgi
chmod 600 "$stage/wpa-repeater.conf" "$stage/settings.env"
chown cfg_wifi:service "$stage/hostapd-repeater.conf" "$stage/hostapd-repeater.psk"
chmod 640 "$stage/hostapd-repeater.conf" "$stage/hostapd-repeater.psk"

if [ -d "$PROJECT_DIR" ]; then
    previous="$PROJECT_DIR.previous.$$"
    mv "$PROJECT_DIR" "$previous"
fi
mv "$stage" "$PROJECT_DIR"

if [ -d "$WEB_DIR" ]; then
    web_previous="$WEB_DIR.previous.$$"
    mv "$WEB_DIR" "$web_previous"
fi
mv "$web_stage" "$WEB_DIR"

feature_tmp=/tmp/hg5r-feature.$$
grep -v 'feature.name="FT_CWMP_NODE_AUDIT_PLUGIN"' "$FEATURE_FILE" >"$feature_tmp" || true
cat "$FILES/audit-feature-line.cfg" >>"$feature_tmp"
cp "$feature_tmp" "$FEATURE_FILE"
rm -f "$feature_tmp"

cp "$FILES/audit-hook.sh" "$CONTROL_HOOK"
chmod 755 "$CONTROL_HOOK"
sync

if [ -n "${previous:-}" ]; then
    "$PROJECT_DIR/busybox-repeater" rm -rf "$previous"
fi
if [ -n "${web_previous:-}" ]; then
    "$PROJECT_DIR/busybox-repeater" rm -rf "$web_previous"
fi

start-stop-daemon -S -b -x "$PROJECT_DIR/repeater_bootstrap.sh"
sleep 3
if [ ! -s /var/run/hg5r-service.pid ]; then
    die "service did not start; run $PROJECT_DIR/doctor.sh"
fi

cat <<EOF
Installed successfully.

Reboot, connect to the configured output SSID, then open:
  http://$LAN_IP:8080

Keep this installation archive for recovery.
EOF
