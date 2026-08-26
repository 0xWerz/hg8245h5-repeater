#!/bin/sh

# Persistent repeater service for the verified HG8245H5 R21 runtime.
PATH=/bin:/sbin:/usr/bin:/usr/sbin
PROFILE=/mnt/jffs2/Install_gram/hg8245h5-repeater/profile.env
[ -r "$PROFILE" ] || exit 1
. "$PROFILE"

BUSYBOX=$PROJECT_DIR/busybox-repeater
WPA=$PROJECT_DIR/wpa_supplicant.hg5r
WPA_CLI=$PROJECT_DIR/wpa_cli
WPA_CONF=$PROJECT_DIR/wpa-repeater.conf
DHCP_SCRIPT=$PROJECT_DIR/udhcpc.script
SETTINGS=$PROJECT_DIR/settings.env
HOSTAPD_CONF=$PROJECT_DIR/hostapd-repeater.conf
WPA_PIDFILE=/var/run/hg5r-wpa.pid
DHCP_PIDFILE=/var/run/hg5r-dhcp.pid
SERVICE_PIDFILE=/var/run/hg5r-service.pid
LEASE_FILE=/var/run/hg5r-lease
GATEWAY_FILE=/var/run/hg5r-gateway
DNS_FILE=/var/run/hg5r-dns
LOCK_DIR=/var/run/hg5r-service.lock
UPSTREAM_CHANNEL=1
UPSTREAM_BSSID=

[ -r "$SETTINGS" ] && . "$SETTINGS"

umask 077
exec >>"$LOG_FILE" 2>&1

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log_msg "service already running"
    exit 0
fi
echo $$ >"$SERVICE_PIDFILE"

cleanup() {
    rm -f "$SERVICE_PIDFILE"
    rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' INT TERM

station_mac() {
    cat "/sys/class/net/$STA_IF/address" 2>/dev/null | tr 'A-F' 'a-f'
}

station_connected() {
    line=$(iwconfig "$STA_IF" 2>/dev/null | grep 'Access Point:' | head -1)
    [ -n "$line" ] && ! printf '%s' "$line" | grep -q '00:00:00:00:00:00'
}

ensure_output_ap() {
    force_restart=$1
    if [ "$force_restart" != force ] && ps ww | grep '[h]ostapd' | grep -q "$HOSTAPD_CONF"; then
        return 0
    fi

    killall hostapd 2>/dev/null || true
    "$BUSYBOX" usleep 400000
    /bin/hostapd -t -e /tmp/myramdom -f /tmp/hg5r-hostapd.log -B "$HOSTAPD_CONF"
    sleep 1
    if ps ww | grep '[h]ostapd' | grep -q "$HOSTAPD_CONF"; then
        log_msg "output AP active on channel $UPSTREAM_CHANNEL"
        return 0
    fi
    log_msg "output AP failed"
    return 1
}

dhcp_running() {
    [ -s "$DHCP_PIDFILE" ] && kill -0 "$(cat "$DHCP_PIDFILE")" 2>/dev/null
}

dhcp_ready() {
    [ -s "$LEASE_FILE" ] && [ -s "$GATEWAY_FILE" ]
}

stop_dhcp() {
    if dhcp_running; then
        kill "$(cat "$DHCP_PIDFILE")" 2>/dev/null || true
        sleep 1
    fi
    rm -f "$DHCP_PIDFILE" "$LEASE_FILE" "$GATEWAY_FILE" "$DNS_FILE"
}

prepare_station_interface() {
    mac=$(station_mac)
    printf '%s' "$mac" | grep -Eq '^([0-9a-f]{2}:){5}[0-9a-f]{2}$' || return 1
    [ "$mac" != 00:00:00:00:00:00 ] || return 1

    ifconfig "$STA_IF" down
    ifconfig "$STA_IF" hw ether "$mac"
    echo "$STA_IF set_oma $mac" >/sys/hisys/hipriv
    iwpriv "$STA_IF" wds_vap_mode 0 >/dev/null 2>&1 || true
    iwconfig "$STA_IF" essid off
    iwpriv "$STA_IF" mode 11g >/dev/null 2>&1 || true
    ifconfig "$STA_IF" up
}

start_station() {
    log_msg "starting uplink on channel $UPSTREAM_CHANNEL"
    stop_dhcp

    if [ -s "$WPA_PIDFILE" ]; then
        "$WPA_CLI" -p /var/run/wpa_supplicant -i "$STA_IF" terminate >/dev/null 2>&1 || true
        sleep 1
    fi
    killall wpa_supplicant.hg5r 2>/dev/null || true
    rm -f "$WPA_PIDFILE"

    iwpriv "$AP_IF" channel "$UPSTREAM_CHANNEL" >/dev/null 2>&1 || true
    ensure_output_ap force
    prepare_station_interface || return 1
    "$WPA" -B -P "$WPA_PIDFILE" -i "$STA_IF" -b "$LAN_IF" -c "$WPA_CONF" -Dnl80211 -e /tmp/myramdom
}

warmup_radio() {
    [ -n "$UPSTREAM_BSSID" ] || return 1
    log_msg "clearing stale association state"

    "$WPA_CLI" -p /var/run/wpa_supplicant -i "$STA_IF" scan >/dev/null 2>&1 || true
    sleep 4
    "$WPA_CLI" -p /var/run/wpa_supplicant -i "$STA_IF" scan_results >/tmp/hg5r-warmup.tsv 2>/dev/null
    line=$(tail -n +2 /tmp/hg5r-warmup.tsv | grep -vi "^$UPSTREAM_BSSID[[:space:]]" | grep '\[WPA' | head -1)
    [ -n "$line" ] || return 1

    bssid=$(printf '%s\n' "$line" | cut -f1)
    frequency=$(printf '%s\n' "$line" | cut -f2)
    ssid=$(printf '%s\n' "$line" | cut -f5-)
    ssid_escaped=$(printf '%s' "$ssid" | sed 's/\\/\\\\/g; s/"/\\"/g')
    if [ "$frequency" = 2484 ]; then
        channel=14
    else
        channel=$(( (frequency - 2407) / 5 ))
    fi

    {
        echo 'ctrl_interface=/var/run/wpa_supplicant'
        echo 'update_config=0'
        echo 'network={'
        printf '    ssid="%s"\n' "$ssid_escaped"
        printf '    bssid=%s\n' "$bssid"
        echo '    psk="00000000"'
        echo '    key_mgmt=WPA-PSK'
        echo '}'
    } >/tmp/hg5r-warmup.conf
    chmod 600 /tmp/hg5r-warmup.conf

    "$WPA_CLI" -p /var/run/wpa_supplicant -i "$STA_IF" terminate >/dev/null 2>&1 || true
    killall wpa_supplicant.hg5r 2>/dev/null || true
    iwpriv "$AP_IF" channel "$channel" >/dev/null 2>&1 || true
    prepare_station_interface || return 1
    "$WPA" -B -P /var/run/hg5r-warmup.pid -i "$STA_IF" -b "$LAN_IF" -c /tmp/hg5r-warmup.conf -Dnl80211 -e /tmp/myramdom
    sleep 8
    "$WPA_CLI" -p /var/run/wpa_supplicant -i "$STA_IF" terminate >/dev/null 2>&1 || true
    killall wpa_supplicant.hg5r 2>/dev/null || true
    rm -f /var/run/hg5r-warmup.pid /tmp/hg5r-warmup.conf
}

start_dhcp() {
    dhcp_running && return
    log_msg "requesting DHCP lease"
    rm -f "$LEASE_FILE" "$GATEWAY_FILE" "$DNS_FILE" "$DHCP_PIDFILE"
    ifconfig "$STA_IF" 0.0.0.0
    "$BUSYBOX" udhcpc -f -i "$STA_IF" -p "$DHCP_PIDFILE" -s "$DHCP_SCRIPT" -t 5 -T 3 -A 3 >/tmp/hg5r-udhcpc.log 2>&1 &
}

configure_routing() {
    gateway=$(head -1 "$GATEWAY_FILE" 2>/dev/null)
    [ -n "$gateway" ] || return 1
    if ! route -n | grep -q "^0.0.0.0[[:space:]]*$gateway"; then
        route del default 2>/dev/null || true
        route add default gw "$gateway" dev "$STA_IF"
    fi
    echo 1 >/proc/sys/net/ipv4/ip_forward
}

install_firewall() {
    gateway=$(head -1 "$GATEWAY_FILE" 2>/dev/null)
    dns_server=$(head -1 "$DNS_FILE" 2>/dev/null)
    [ -n "$dns_server" ] || dns_server=$gateway
    [ -n "$dns_server" ] || return 1

    iptables -t mangle -N HG5R_MARK 2>/dev/null || true
    iptables -t mangle -F HG5R_MARK
    while iptables -t mangle -D PREROUTING -j HG5R_MARK 2>/dev/null; do :; done
    iptables -t mangle -A HG5R_MARK -i "$LAN_IF" -s "$LAN_CIDR" -j MARK --set-mark 0
    iptables -t mangle -I PREROUTING 1 -j HG5R_MARK

    iptables -t nat -N HG5R_NAT 2>/dev/null || true
    iptables -t nat -F HG5R_NAT
    while iptables -t nat -D POSTROUTING -j HG5R_NAT 2>/dev/null; do :; done
    iptables -t nat -A HG5R_NAT -s "$LAN_CIDR" -o "$STA_IF" -j MASQUERADE
    iptables -t nat -I POSTROUTING 1 -j HG5R_NAT

    iptables -N HG5R_FWD 2>/dev/null || true
    iptables -F HG5R_FWD
    while iptables -D FORWARD -j HG5R_FWD 2>/dev/null; do :; done
    iptables -A HG5R_FWD -i "$STA_IF" -o "$LAN_IF" -d "$LAN_CIDR" -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A HG5R_FWD -i "$LAN_IF" -o "$STA_IF" -s "$LAN_CIDR" -j ACCEPT
    iptables -I FORWARD 1 -j HG5R_FWD

    iptables -t nat -N HG5R_DNS 2>/dev/null || true
    iptables -t nat -F HG5R_DNS
    while iptables -t nat -D PREROUTING -j HG5R_DNS 2>/dev/null; do :; done
    iptables -t nat -A HG5R_DNS -i "$LAN_IF" -s "$LAN_CIDR" -p udp --dport 53 -j DNAT --to-destination "$dns_server"
    iptables -t nat -A HG5R_DNS -i "$LAN_IF" -s "$LAN_CIDR" -p tcp --dport 53 -j DNAT --to-destination "$dns_server"
    iptables -t nat -I PREROUTING 1 -j HG5R_DNS
}

ensure_web_ui() {
    if ! netstat -lnt 2>/dev/null | grep -q ':8080 '; then
        "$BUSYBOX" httpd -p "$LAN_IP:8080" -h "$WEB_DIR"
        log_msg "setup UI listening on $LAN_IP:8080"
    fi
}

log_msg "service starting"

attempt=0
while [ "$attempt" -lt 120 ]; do
    if [ -d "/sys/class/net/$AP_IF" ] && [ -d "/sys/class/net/$STA_IF" ] && pidof hostapd >/dev/null 2>&1 && [ -w /sys/hisys/hipriv ]; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 2
done
[ "$attempt" -lt 120 ] || { log_msg "stock Wi-Fi did not become ready"; exit 1; }

ensure_web_ui
iwpriv "$AP_IF" channel "$UPSTREAM_CHANNEL" >/dev/null 2>&1 || true
ensure_output_ap normal

if ! station_connected; then
    start_station
    attempt=0
    while [ "$attempt" -lt 12 ]; do
        station_connected && break
        attempt=$((attempt + 1))
        sleep 2
    done
    if ! station_connected; then
        warmup_radio || true
        start_station
        attempt=0
        while [ "$attempt" -lt 30 ]; do
            station_connected && break
            attempt=$((attempt + 1))
            sleep 2
        done
    fi
fi

if station_connected; then
    start_dhcp
    attempt=0
    while [ "$attempt" -lt 30 ]; do
        dhcp_ready && break
        attempt=$((attempt + 1))
        sleep 1
    done
fi

if station_connected && dhcp_ready; then
    configure_routing
    install_firewall
    log_msg "uplink ready"
else
    log_msg "initial uplink incomplete; watchdog active"
fi

was_ready=0
failure_count=0
while :; do
    ensure_web_ui
    ensure_output_ap normal
    if station_connected; then
        if ! dhcp_running && ! dhcp_ready; then
            start_dhcp
        fi
        if dhcp_ready; then
            configure_routing
            if [ "$was_ready" -eq 0 ] || ! iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -q HG5R_NAT; then
                install_firewall
                log_msg "uplink ready"
            fi
            was_ready=1
            failure_count=0
        else
            was_ready=0
        fi
    else
        [ "$was_ready" -eq 1 ] && log_msg "uplink lost"
        was_ready=0
        failure_count=$((failure_count + 1))
        if [ "$failure_count" -ge 2 ]; then
            warmup_radio || true
            failure_count=0
        fi
        start_station || true
    fi
    sleep 15
done
