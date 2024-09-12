#!/bin/sh
set -e

# Function to generate Privoxy configuration
generate_privoxy_config() {
    local config_file="/etc/privoxy/config"
    cat << EOF > "$config_file"
listen-address ${PRIVOXY_LISTEN_ADDRESS}
forward-socks5 / localhost:8050 .
toggle ${PRIVOXY_TOGGLE}
accept-intercepted-requests ${PRIVOXY_ACCEPT_INTERCEPTED_REQUESTS}
buffer-limit ${PRIVOXY_BUFFER_LIMIT}
enable-proxy-authentication-forwarding ${PRIVOXY_ENABLE_PROXY_AUTHENTICATION_FORWARDING}
debug ${PRIVOXY_DEBUG}
EOF
    echo "Generated Privoxy config: $config_file"
}

# Function to generate HAProxy configuration
generate_haproxy_config() {
    local config_file="/etc/haproxy/haproxy.cfg"
    cat << EOF > "$config_file"
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
        echo "    server tor$i 127.0.0.1:905$i check" >> "$config_file"
    done
    echo "Generated HAProxy config: $config_file"
}

# Function to generate Tor configuration
generate_tor_config() {
    local instance=$1
    local config_file="/etc/tor/torrc-$instance"
    cat << EOF > "$config_file"
SocksPort 905$instance
DNSPort 535$instance
RelayBandwidthRate ${TOR_BANDWIDTH_RATE}
RelayBandwidthBurst ${TOR_BANDWIDTH_BURST}
NewCircuitPeriod ${TOR_NEW_CIRCUIT_PERIOD}
MaxCircuitDirtiness ${TOR_MAX_CIRCUIT_DIRTINESS}
CircuitBuildTimeout ${TOR_CIRCUIT_BUILD_TIMEOUT}
DataDirectory /var/lib/tor/$instance
Log notice stdout
EOF
    echo "Generated Tor config: $config_file"
}

# Generate configurations
generate_privoxy_config
generate_haproxy_config
for i in $(seq 0 $((NUM_TOR_INSTANCES - 1))); do
    generate_tor_config $i
    mkdir -p /var/lib/tor/$i
    chown -R tor /var/lib/tor
done

# Start Privoxy
echo "Starting Privoxy"
privoxy --no-daemon /etc/privoxy/config &

# Start HAProxy
echo "Starting HAProxy"
haproxy -f /etc/haproxy/haproxy.cfg &

# Start Tor instances
for i in $(seq 0 $((NUM_TOR_INSTANCES - 1))); do
    config_file="/etc/tor/torrc-$i"
    if [ -f "$config_file" ]; then
        echo "Starting Tor instance $i with config: $config_file"
        gosu tor tor -f "$config_file" &
    else
        echo "Error: Tor config file not found: $config_file"
        exit 1
    fi
done

# Wait for all background processes
wait
