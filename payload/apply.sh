#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin
PROJECT_DIR=/mnt/jffs2/Install_gram/hg8245h5-repeater
exec >/tmp/hg5r-apply.log 2>&1
sleep 2

"$PROJECT_DIR/wpa_cli" -p /var/run/wpa_supplicant -i vap8 disconnect >/dev/null 2>&1 || true
sleep 1

if [ -s /var/run/hg5r-service.pid ]; then
    service_pid=$(cat /var/run/hg5r-service.pid)
    kill "$service_pid" 2>/dev/null || true
    sleep 2
    kill -9 "$service_pid" 2>/dev/null || true
fi

"$PROJECT_DIR/wpa_cli" -p /var/run/wpa_supplicant -i vap8 terminate >/dev/null 2>&1 || true
killall wpa_supplicant.hg5r 2>/dev/null || true
if [ -s /var/run/hg5r-dhcp.pid ]; then
    kill "$(cat /var/run/hg5r-dhcp.pid)" 2>/dev/null || true
fi
rmdir /var/run/hg5r-service.lock 2>/dev/null || true
start-stop-daemon -S -b -x "$PROJECT_DIR/repeater_bootstrap.sh"
