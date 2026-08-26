#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin
PROJECT_DIR=/mnt/jffs2/Install_gram/hg8245h5-repeater
BUSYBOX=$PROJECT_DIR/busybox-repeater
CACHE=/tmp/hg5r-scan.tsv
CONF=$PROJECT_DIR/wpa-repeater.conf
SETTINGS=$PROJECT_DIR/settings.env

umask 077
IFS= read -r post_data

field() {
    printf '%s' "$post_data" | tr '&' '\n' | sed -n "s/^$1=//p" | head -1
}

decode() {
    "$BUSYBOX" httpd -d "$1"
}

fail() {
    printf 'Status: 400 Bad Request\r\nContent-Type: text/html; charset=utf-8\r\n\r\n'
    printf '<!doctype html><meta name="viewport" content="width=device-width"><body style="background:#10130f;color:#f3f1e8;font:16px sans-serif;padding:30px"><h1>Could not save</h1><p>%s</p><p><a style="color:#c8ff45" href="/">Return to setup</a></p></body>' "$1"
    exit 0
}

network=$(decode "$(field network)")
manual_ssid=$(decode "$(field manual_ssid)")
manual_channel=$(decode "$(field manual_channel)")
password=$(decode "$(field password)")

password_length=$(printf '%s' "$password" | wc -c | tr -d ' ')
[ "$password_length" -ge 8 ] 2>/dev/null && [ "$password_length" -le 63 ] 2>/dev/null || fail 'The Wi-Fi password must contain 8–63 characters.'
printf '%s' "$password" | grep -q '[[:cntrl:]]' && fail 'Control characters are not allowed in the password.'

bssid=
if [ -n "$network" ]; then
    printf '%s' "$network" | grep -Eq '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$' || fail 'The selected access point identifier is invalid.'
    line=$(grep -i "^$network[[:space:]]" "$CACHE" 2>/dev/null | head -1)
    [ -n "$line" ] || fail 'That scan result expired. Scan again.'
    frequency=$(printf '%s\n' "$line" | cut -f2)
    ssid=$(printf '%s\n' "$line" | cut -f5-)
    bssid=$network
    if [ "$frequency" = 2484 ]; then
        channel=14
    else
        channel=$(( (frequency - 2407) / 5 ))
    fi
else
    ssid=$manual_ssid
    channel=$manual_channel
fi

ssid_length=$(printf '%s' "$ssid" | wc -c | tr -d ' ')
[ "$ssid_length" -ge 1 ] 2>/dev/null && [ "$ssid_length" -le 32 ] 2>/dev/null || fail 'The SSID must contain 1–32 bytes.'
printf '%s' "$ssid" | grep -q '[[:cntrl:]]' && fail 'Control characters are not allowed in the SSID.'
case "$channel" in 1|2|3|4|5|6|7|8|9|10|11|12|13|14) ;; *) fail 'The selected channel is invalid.' ;; esac

ssid_wpa=$(printf '%s' "$ssid" | sed 's/\\/\\\\/g; s/"/\\"/g')
password_wpa=$(printf '%s' "$password" | sed 's/\\/\\\\/g; s/"/\\"/g')

{
    echo 'ctrl_interface=/var/run/wpa_supplicant'
    echo 'update_config=0'
    echo 'ap_scan=1'
    echo 'network={'
    printf '    ssid="%s"\n' "$ssid_wpa"
    [ -n "$bssid" ] && printf '    bssid=%s\n' "$bssid"
    printf '    psk="%s"\n' "$password_wpa"
    echo '    key_mgmt=WPA-PSK'
    echo '    proto=RSN'
    echo '    pairwise=CCMP'
    echo '    group=CCMP TKIP'
    echo '    scan_ssid=1'
    echo '}'
} >"$CONF.new"

{
    printf 'UPSTREAM_CHANNEL=%s\n' "$channel"
    printf 'UPSTREAM_BSSID=%s\n' "$bssid"
} >"$SETTINGS.new"

chmod 600 "$CONF.new" "$SETTINGS.new"
mv "$CONF.new" "$CONF"
mv "$SETTINGS.new" "$SETTINGS"
sync
start-stop-daemon -S -b -x "$PROJECT_DIR/apply.sh"

ssid_html=$(printf '%s' "$ssid" | sed 's/\&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
printf 'Content-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\n\r\n'
printf '<!doctype html><meta name="viewport" content="width=device-width"><meta http-equiv="refresh" content="18;url=/"><body style="margin:0;background:#10130f;color:#f3f1e8;font-family:Georgia,serif;display:grid;place-items:center;min-height:100vh"><main style="width:min(520px,calc(100%% - 36px));border:1px solid #343b30;padding:28px;background:#191d18"><div style="color:#c8ff45;font:700 11px monospace;letter-spacing:.15em">SETTINGS SAVED</div><h1 style="font-weight:400;font-size:42px;line-height:1;margin:12px 0">Moving the signal.</h1><p style="color:#a5ad9f;line-height:1.6">Connecting to <strong style="color:#f3f1e8">%s</strong> on channel %s. The output Wi-Fi may disappear briefly.</p><a style="color:#10130f;background:#c8ff45;padding:11px 15px;display:inline-block;text-decoration:none;font:bold 12px sans-serif;margin-top:8px" href="/">CHECK STATUS</a></main></body>' "$ssid_html" "$channel"
