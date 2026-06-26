#!/bin/sh
set -eu

CHILD_PIDS=""
SHUTTING_DOWN=0
STOP_GRACE_PERIOD=8

TOR_PORT_BLOCK_BASE=9050
TOR_PORT_BLOCK_STRIDE=3
TOR_SOCKS_PORT_OFFSET=0
TOR_HTTP_TUNNEL_PORT_OFFSET=1
MAX_PORT=65535
MAX_NUMERIC_SECONDS=2147483647
MAX_BANDWIDTH_AMOUNT=999999999999

DEFAULT_NUM_TOR_INSTANCES=3
DEFAULT_TOR_BANDWIDTH_BURST="1 GByte"
DEFAULT_TOR_BANDWIDTH_RATE="1 GByte"
DEFAULT_TOR_NEW_CIRCUIT_PERIOD=30
DEFAULT_TOR_MAX_CIRCUIT_DIRTINESS=600
DEFAULT_TOR_CIRCUIT_BUILD_TIMEOUT=60

die() {
	echo "Error: $*" >&2
	exit 1
}

reject_multiline_value() {
	name="$1"
	value="$2"

	case "$value" in
	*'
'*)
		die "$name must not contain newline characters"
		;;
	esac
}

validate_decimal_integer_range() {
	name="$1"
	value="$2"
	min="$3"
	max="$4"

	case "$value" in
	'' | *[!0-9]*)
		die "$name must be a decimal integer"
		;;
	esac

	case "$value" in
	0 | [1-9]*)
		;;
	*)
		die "$name must not contain leading zeroes"
		;;
	esac

	if [ "${#value}" -gt "${#max}" ] || { [ "${#value}" -eq "${#max}" ] && [ "$value" -gt "$max" ]; }; then
		die "$name must be less than or equal to $max"
	fi

	if [ "$value" -lt "$min" ]; then
		die "$name must be greater than or equal to $min"
	fi
}

validate_bandwidth() {
	name="$1"
	value="$2"

	set -f
	set -- $value
	set +f

	if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
		die "$name must be a decimal amount optionally followed by a supported Tor bandwidth unit"
	fi

	amount="$1"
	unit="${2:-}"

	validate_decimal_integer_range "$name amount" "$amount" 1 "$MAX_BANDWIDTH_AMOUNT"

	case "$unit" in
	'' | Byte | Bytes | KByte | KBytes | MByte | MBytes | GByte | GBytes | TByte | TBytes)
		;;
	*)
		die "$name unit must be one of: Byte, Bytes, KByte, KBytes, MByte, MBytes, GByte, GBytes, TByte, TBytes"
		;;
	esac
}

tor_instance_port() {
	instance="$1"
	offset="$2"

	echo $((TOR_PORT_BLOCK_BASE + instance * TOR_PORT_BLOCK_STRIDE + offset))
}

tor_socks_port() {
	tor_instance_port "$1" "$TOR_SOCKS_PORT_OFFSET"
}

tor_http_tunnel_port() {
	tor_instance_port "$1" "$TOR_HTTP_TUNNEL_PORT_OFFSET"
}

max_tor_instances() {
	last_port_in_first_block=$((TOR_PORT_BLOCK_BASE + TOR_PORT_BLOCK_STRIDE - 1))

	echo $(((MAX_PORT - last_port_in_first_block) / TOR_PORT_BLOCK_STRIDE + 1))
}

set_defaults() {
	: "${NUM_TOR_INSTANCES:=$DEFAULT_NUM_TOR_INSTANCES}"

	: "${TOR_BANDWIDTH_BURST:=$DEFAULT_TOR_BANDWIDTH_BURST}"
	: "${TOR_BANDWIDTH_RATE:=$DEFAULT_TOR_BANDWIDTH_RATE}"
	: "${TOR_NEW_CIRCUIT_PERIOD:=$DEFAULT_TOR_NEW_CIRCUIT_PERIOD}"
	: "${TOR_MAX_CIRCUIT_DIRTINESS:=$DEFAULT_TOR_MAX_CIRCUIT_DIRTINESS}"
	: "${TOR_CIRCUIT_BUILD_TIMEOUT:=$DEFAULT_TOR_CIRCUIT_BUILD_TIMEOUT}"
}

validate_environment() {
	reject_multiline_value "NUM_TOR_INSTANCES" "$NUM_TOR_INSTANCES"
	reject_multiline_value "TOR_BANDWIDTH_BURST" "$TOR_BANDWIDTH_BURST"
	reject_multiline_value "TOR_BANDWIDTH_RATE" "$TOR_BANDWIDTH_RATE"
	reject_multiline_value "TOR_NEW_CIRCUIT_PERIOD" "$TOR_NEW_CIRCUIT_PERIOD"
	reject_multiline_value "TOR_MAX_CIRCUIT_DIRTINESS" "$TOR_MAX_CIRCUIT_DIRTINESS"
	reject_multiline_value "TOR_CIRCUIT_BUILD_TIMEOUT" "$TOR_CIRCUIT_BUILD_TIMEOUT"

	max_instances="$(max_tor_instances)"

	validate_decimal_integer_range "NUM_TOR_INSTANCES" "$NUM_TOR_INSTANCES" 1 "$max_instances"
	validate_bandwidth "TOR_BANDWIDTH_BURST" "$TOR_BANDWIDTH_BURST"
	validate_bandwidth "TOR_BANDWIDTH_RATE" "$TOR_BANDWIDTH_RATE"
	validate_decimal_integer_range "TOR_NEW_CIRCUIT_PERIOD" "$TOR_NEW_CIRCUIT_PERIOD" 1 "$MAX_NUMERIC_SECONDS"
	validate_decimal_integer_range "TOR_MAX_CIRCUIT_DIRTINESS" "$TOR_MAX_CIRCUIT_DIRTINESS" 1 "$MAX_NUMERIC_SECONDS"
	validate_decimal_integer_range "TOR_CIRCUIT_BUILD_TIMEOUT" "$TOR_CIRCUIT_BUILD_TIMEOUT" 1 "$MAX_NUMERIC_SECONDS"
}

generate_haproxy_config() {
	config_file="/etc/haproxy/haproxy.cfg"

	cat <<EOF >"$config_file"
global
    maxconn 256

defaults
    mode tcp
    timeout connect 5000ms
    timeout client 1h
    timeout server 1h
    timeout tunnel 1h

frontend socks5_frontend
    bind 0.0.0.0:8050
    default_backend tor_socks5_backend

backend tor_socks5_backend
    balance roundrobin
EOF

	i=0
	while [ "$i" -lt "$NUM_TOR_INSTANCES" ]; do
		socks_port="$(tor_socks_port "$i")"
		echo "    server tor-socks5-$i 127.0.0.1:$socks_port check" >>"$config_file"
		i=$((i + 1))
	done

	cat <<EOF >>"$config_file"

frontend http_connect_frontend
    bind 0.0.0.0:8118
    default_backend tor_http_connect_backend

backend tor_http_connect_backend
    balance roundrobin
EOF

	i=0
	while [ "$i" -lt "$NUM_TOR_INSTANCES" ]; do
		http_tunnel_port="$(tor_http_tunnel_port "$i")"
		echo "    server tor-http-connect-$i 127.0.0.1:$http_tunnel_port check" >>"$config_file"
		i=$((i + 1))
	done

	echo "Generated HAProxy config: $config_file"
}

generate_tor_config() {
	instance="$1"
	socks_port="$(tor_socks_port "$instance")"
	http_tunnel_port="$(tor_http_tunnel_port "$instance")"
	config_file="/etc/tor/torrc-$instance"

	cat <<EOF >"$config_file"
SocksPort 127.0.0.1:${socks_port}
HTTPTunnelPort 127.0.0.1:${http_tunnel_port}
BandwidthRate ${TOR_BANDWIDTH_RATE}
BandwidthBurst ${TOR_BANDWIDTH_BURST}
NewCircuitPeriod ${TOR_NEW_CIRCUIT_PERIOD}
MaxCircuitDirtiness ${TOR_MAX_CIRCUIT_DIRTINESS}
CircuitBuildTimeout ${TOR_CIRCUIT_BUILD_TIMEOUT}
DataDirectory /var/lib/tor/${instance}
Log notice stdout
EOF

	echo "Generated Tor config: $config_file"
}

prepare_tor_data_directories() {
	mkdir -p /var/lib/tor

	i=0
	while [ "$i" -lt "$NUM_TOR_INSTANCES" ]; do
		mkdir -p "/var/lib/tor/$i"
		i=$((i + 1))
	done

	chown -R tor:tor /var/lib/tor
}

verify_configs() {
	echo "Verifying HAProxy config"
	haproxy -c -f /etc/haproxy/haproxy.cfg

	i=0
	while [ "$i" -lt "$NUM_TOR_INSTANCES" ]; do
		echo "Verifying Tor config for instance $i"
		su-exec tor:tor tor -f "/etc/tor/torrc-$i" --verify-config
		i=$((i + 1))
	done
}

start_process() {
	name="$1"
	shift

	echo "Starting $name"
	"$@" &
	pid="$!"
	CHILD_PIDS="$CHILD_PIDS $pid"
	echo "$name started with PID $pid"
}

shutdown() {
	if [ "$SHUTTING_DOWN" -eq 1 ]; then
		return
	fi

	SHUTTING_DOWN=1
	trap - TERM INT

	if [ -z "$CHILD_PIDS" ]; then
		return
	fi

	echo "Stopping child processes"
	kill -TERM $CHILD_PIDS 2>/dev/null || true

	sleep "$STOP_GRACE_PERIOD"

	kill -KILL $CHILD_PIDS 2>/dev/null || true
	wait $CHILD_PIDS 2>/dev/null || true
}

main() {
	set_defaults
	validate_environment

	trap 'shutdown; exit 143' TERM
	trap 'shutdown; exit 130' INT

	generate_haproxy_config

	i=0
	while [ "$i" -lt "$NUM_TOR_INSTANCES" ]; do
		generate_tor_config "$i"
		i=$((i + 1))
	done

	prepare_tor_data_directories
	verify_configs

	i=0
	while [ "$i" -lt "$NUM_TOR_INSTANCES" ]; do
		start_process "Tor instance $i" su-exec tor:tor tor -f "/etc/tor/torrc-$i"
		i=$((i + 1))
	done

	start_process "HAProxy" su-exec haproxy:haproxy haproxy -W -db -f /etc/haproxy/haproxy.cfg

	set +e
	wait -n
	status="$?"
	set -e

	echo "A critical process exited with status $status; stopping remaining processes"
	shutdown

	if [ "$status" -eq 0 ] || [ "$status" -eq 127 ]; then
		exit 1
	fi

	exit "$status"
}

main "$@"
