#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin
PROJECT_DIR=/mnt/jffs2/Install_gram/hg8245h5-repeater
WPA_CLI=$PROJECT_DIR/wpa_cli

printf 'Content-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\n\r\n'

status=$($WPA_CLI -p /var/run/wpa_supplicant -i vap8 status 2>/dev/null)
state=$(printf '%s\n' "$status" | sed -n 's/^wpa_state=//p' | head -1)
ssid=$(printf '%s\n' "$status" | sed -n 's/^ssid=//p' | head -1)
bssid=$(printf '%s\n' "$status" | sed -n 's/^bssid=//p' | head -1)
ip=$(ifconfig vap8 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p' | head -1)
ssid_html=$(printf '%s' "$ssid" | sed 's/\&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

if [ "$state" = COMPLETED ] && [ -n "$ip" ]; then
    printf '<div class="status-copy"><div class="status-title">Repeating %s</div><div class="status-meta">UPLINK %s · DHCP %s</div></div><span class="lamp on"></span>\n' "$ssid_html" "$bssid" "$ip"
elif [ "$state" = COMPLETED ]; then
    printf '<div class="status-copy"><div class="status-title">Wi-Fi linked; requesting an address</div><div class="status-meta">DHCP PENDING</div></div><span class="lamp"></span>\n'
else
    [ -n "$state" ] || state=STARTING
    printf '<div class="status-copy"><div class="status-title">Uplink is not ready</div><div class="status-meta">STATE %s · WATCHDOG ACTIVE</div></div><span class="lamp"></span>\n' "$state"
fi
