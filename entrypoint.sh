#!/bin/sh
set -e

# Function to generate Tor configuration
generate_tor_config() {
    local instance=$1
    cat << EOF > /etc/tor/torrc_$instance
SocksPort 905$instance
ControlPort 905$(($instance + 1))
DNSPort 535$instance
BridgeRelay ${TOR_RELAY}
Nickname ${TOR_NICKNAME}_$instance
RelayBandwidthRate ${TOR_BANDWIDTH_RATE}
RelayBandwidthBurst ${TOR_BANDWIDTH_BURST}
ExitPolicy ${TOR_EXIT_POLICY}
DataDirectory /var/lib/tor/$instance
Log notice stdout
EOF
}

# Function to generate Privoxy configuration
generate_privoxy_config() {
    cat << EOF > /etc/privoxy/config
listen-address ${PRIVOXY_LISTEN_ADDRESS}
forward-socks5 / localhost:8050 .
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

# Function to generate HAProxy configuration
generate_haproxy_config() {
    cat << EOF > /etc/haproxy/haproxy.cfg
global
    daemon
    maxconn 256

defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend tor_frontend
    bind *:8050
    default_backend tor_backend

backend tor_backend
    balance roundrobin
EOF

    for i in $(seq 0 $((NUM_TOR_INSTANCES - 1))); do
        echo "    server tor$i 127.0.0.1:905$i check" >> /etc/haproxy/haproxy.cfg
    done
}

# Generate configurations
for i in $(seq 0 $((NUM_TOR_INSTANCES - 1))); do
    generate_tor_config $i
    mkdir -p /var/lib/tor/$i
    chown -R 101:65533 /var/lib/tor/$i
done

generate_privoxy_config
generate_haproxy_config

# Set correct permissions
chown -R 101:65533 /etc/tor
chown -R 100:101 /etc/privoxy

# Start Tor instances
for i in $(seq 0 $((NUM_TOR_INSTANCES - 1))); do
    gosu tor tor -f /etc/tor/torrc_$i &
done

# Start HAProxy
haproxy -f /etc/haproxy/haproxy.cfg &

# Start Privoxy
exec gosu privoxy privoxy --no-daemon /etc/privoxy/config
