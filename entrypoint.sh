#!/bin/sh
set -e

# Function to generate Tor configuration
generate_tor_config() {
    cat << EOF > /etc/tor/torrc
SocksPort ${TOR_SOCKS_PORT}
ControlPort ${TOR_CONTROL_PORT}
DNSPort ${TOR_DNS_PORT}
BridgeRelay ${TOR_RELAY}
Nickname ${TOR_NICKNAME}
RelayBandwidthRate ${TOR_BANDWIDTH_RATE}
RelayBandwidthBurst ${TOR_BANDWIDTH_BURST}
ExitPolicy ${TOR_EXIT_POLICY}
DataDirectory /var/lib/tor
Log notice stdout
EOF
}

# Function to generate Privoxy configuration
generate_privoxy_config() {
    cat << EOF > /etc/privoxy/config
listen-address ${PRIVOXY_LISTEN_ADDRESS}
forward-socks5 ${PRIVOXY_FORWARD_SOCKS5}
toggle ${PRIVOXY_TOGGLE}
enable-remote-toggle ${PRIVOXY_ENABLE_REMOTE_TOGGLE}
enable-edit-actions ${PRIVOXY_ENABLE_EDIT_ACTIONS}
accept-intercepted-requests ${PRIVOXY_ACCEPT_INTERCEPTED_REQUESTS}
buffer-limit ${PRIVOXY_BUFFER_LIMIT}
enable-proxy-authentication-forwarding ${PRIVOXY_ENABLE_PROXY_AUTHENTICATION_FORWARDING}
logfile ${PRIVOXY_LOGFILE}
debug ${PRIVOXY_DEBUG}
EOF
}

# Generate configurations
generate_tor_config
generate_privoxy_config

# Set correct permissions
chown -R 101:65533 /etc/tor /var/lib/tor
chown -R 100:101 /etc/privoxy

# Start Tor and Privoxy
exec gosu tor tor -f /etc/tor/torrc & \
exec gosu privoxy privoxy --no-daemon /etc/privoxy/config
