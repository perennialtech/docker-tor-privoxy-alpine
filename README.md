# docker-tor-privoxy-alpine

A Docker image that combines Tor and Privoxy on Alpine Linux, providing a proxy setup with enhanced routing capabilities.

## Project Overview

This project offers a Docker container that integrates Tor and Privoxy on an Alpine Linux base. It's designed to provide a small-footprint proxy solution that can be easily deployed using Docker.

```mermaid
graph LR
    Client[Client] -->|HTTP/HTTPS| Privoxy[Privoxy :8118]
    Privoxy -->|SOCKS5| Tor[Tor :9050]
    Tor --> Internet[Internet]
```

## Components

- **Base Image**: Alpine Linux 3.7
- **Tor**: Onion routing network for secure internet access
- **Privoxy**: Non-caching web proxy with advanced filtering capabilities
- **runit**: Init scheme and service supervision
- **tini**: A minimal init system for containers

## Usage

To run the container with default settings:

```bash
docker run -d -p 8118:8118 -p 9050:9050 rdsubhas/tor-privoxy-alpine
```

To use the proxy:

```bash
curl --proxy localhost:8118 https://www.example.com
```

## Configuration

### Privoxy Configuration

You can customize the Privoxy configuration using environment variables. Here are the available options:

- `PRIVOXY_LISTEN_ADDRESS`: The address and port Privoxy listens on (default: 0.0.0.0:8118)
- `PRIVOXY_FORWARD_SOCKS5`: The SOCKS5 proxy to forward to (default: /localhost:9050)
- `PRIVOXY_TOGGLE`: Enable/disable filtering (default: 1)
- `PRIVOXY_ENABLE_REMOTE_TOGGLE`: Allow remote toggling (default: 0)
- `PRIVOXY_ENABLE_EDIT_ACTIONS`: Allow editing actions (default: 0)
- `PRIVOXY_ENABLE_COMPRESSION`: Enable compression (default: 0)
- `PRIVOXY_ACCEPT_INTERCEPTED_REQUESTS`: Accept intercepted requests (default: 0)
- `PRIVOXY_BUFFER_LIMIT`: Limit on buffer size (default: 4096)
- `PRIVOXY_ENABLE_PROXY_AUTHENTICATION_FORWARDING`: Enable proxy authentication forwarding (default: 0)

### Tor Configuration

You can customize the Tor configuration using environment variables. Here are the available options:

- `TOR_SOCKS_PORT`: The port for Tor's SOCKS proxy (default: 9050)
- `TOR_CONTROL_PORT`: The port for Tor's control protocol (default: 9051)
- `TOR_DNS_PORT`: The port for Tor's DNS server (default: 5353)
- `TOR_RELAY`: Enable/disable relay mode (default: 0)
- `TOR_NICKNAME`: Nickname for the Tor relay (default: TorPrivoxyAlpineRelay)
- `TOR_BANDWIDTH_RATE`: Bandwidth rate limit for the Tor relay (default: 1000000)
- `TOR_BANDWIDTH_BURST`: Bandwidth burst limit for the Tor relay (default: 2000000)
- `TOR_EXIT_POLICY`: Exit policy for the Tor relay (default: "reject *:*")

Example usage with custom configuration:

```bash
docker run -d -p 8118:8118 -p 9050:9050 \
  -e PRIVOXY_LISTEN_ADDRESS=0.0.0.0:8080 \
  -e PRIVOXY_ENABLE_COMPRESSION=1 \
  -e TOR_SOCKS_PORT=9060 \
  -e TOR_RELAY=1 \
  -e TOR_NICKNAME=MyTorRelay \
  rdsubhas/tor-privoxy-alpine
```

### Dockerfile

The Dockerfile specifies the following:

- Base image: Alpine 3.7
- Exposed ports: 8118 and 9050
- Installed packages: privoxy, tor, runit, tini
- Copies service configurations from `service/` to `/etc/service/`
- Sets default environment variables for Privoxy and Tor configuration
- Entrypoint: tini
- CMD: runsvdir /etc/service

### Privoxy

- **Config file**: Dynamically generated based on environment variables
- **Listen address**: Configurable via `PRIVOXY_LISTEN_ADDRESS`
- **Forward to Tor**: Configurable via `PRIVOXY_FORWARD_SOCKS5`
- **Run script**: `/etc/service/privoxy/run` (generates config and starts Privoxy in non-daemon mode)

### Tor

- **Config file**: Dynamically generated based on environment variables
- **SOCKS port**: Configurable via `TOR_SOCKS_PORT`
- **Run script**: `/etc/service/tor/run` (generates config and starts Tor)

## Exposed Ports

- 8118: Privoxy HTTP(S) proxy (configurable)
- 9050: Tor SOCKS5 proxy (configurable)

## Building

To build the image yourself:

```bash
docker build -t tor-privoxy-alpine .
```

## License

This project is licensed under the MIT license. Refer to the LICENSE file in the repository for full details.
