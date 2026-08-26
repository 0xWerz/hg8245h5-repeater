#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin
PROJECT_DIR=/mnt/jffs2/Install_gram/hg8245h5-repeater
WPA_CLI=$PROJECT_DIR/wpa_cli
CACHE=/tmp/hg5r-scan.tsv

printf 'Content-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\n\r\n'

$WPA_CLI -p /var/run/wpa_supplicant -i vap8 scan >/dev/null 2>&1
sleep 4
$WPA_CLI -p /var/run/wpa_supplicant -i vap8 scan_results >"$CACHE" 2>/dev/null

current=$($WPA_CLI -p /var/run/wpa_supplicant -i vap8 status 2>/dev/null)
current_bssid=$(printf '%s\n' "$current" | sed -n 's/^bssid=//p' | head -1)
current_ssid=$(printf '%s\n' "$current" | sed -n 's/^ssid=//p' | head -1)
if [ -n "$current_bssid" ] && ! grep -qi "^${current_bssid}[[:space:]]" "$CACHE"; then
    current_channel=$(iwconfig vap8 2>/dev/null | sed -n 's/.*Channel:\([0-9]*\).*/\1/p' | head -1)
    current_frequency=$((2407 + current_channel * 5))
    printf '%s\t%s\t0\t[CURRENT]\t%s\n' "$current_bssid" "$current_frequency" "$current_ssid" >>"$CACHE"
fi

tail -n +2 "$CACHE" 2>/dev/null | awk -F '\t' '
function esc(s) {
    gsub(/\&/, "\&amp;", s)
    gsub(/</, "\&lt;", s)
    gsub(/>/, "\&gt;", s)
    gsub(/"/, "\&quot;", s)
    return s
}
function channel(freq) {
    if (freq == 2484) return 14
    if (freq >= 2412 && freq <= 2472) return int((freq - 2407) / 5)
    return 0
}
BEGIN { count = 0 }
$1 ~ /^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/ && NF >= 5 {
    ssid = $5
    for (i = 6; i <= NF; i++) ssid = ssid "\t" $i
    if (ssid == "") ssid = "(hidden network)"
    printf "<button type=\"button\" class=\"network\" data-network=\"%s\"><span><strong>%s</strong><small>%s · channel %d</small></span><span class=\"signal\">%s dBm</span></button>\n", $1, esc(ssid), $1, channel($2), $3
    count++
}
END {
    if (count == 0) print "<div class=\"empty\">No networks returned. Enter the SSID and channel manually.</div>"
}'
