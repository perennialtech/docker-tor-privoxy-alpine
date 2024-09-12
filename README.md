# multi-tor-proxy

A Docker image that combines multiple Tor instances, HAProxy for load balancing, and Privoxy on Alpine Linux, providing a scalable proxy setup with enhanced routing capabilities and Tor data persistence.

## Project Overview

This project offers a Docker container that integrates multiple Tor instances, HAProxy for load balancing, and Privoxy on an Alpine Linux base. It's designed to provide a scalable, small-footprint proxy solution that can be easily deployed using Docker, with the added benefit of Tor data persistence across container restarts.

```mermaid
graph LR
    Client[Client] -->|HTTP/HTTPS| Privoxy[Privoxy :8118]
    Privoxy -->|SOCKS5| HAProxy[HAProxy :8050]
    HAProxy -->|SOCKS5| Tor1[Tor Instance 1]
    HAProxy -->|SOCKS5| Tor2[Tor Instance 2]
    HAProxy -->|SOCKS5| TorN[Tor Instance N]
    Tor1 --> Internet[Internet]
    Tor2 --> Internet
    TorN --> Internet
    Tor1 <-->|Persistent Data| Volume[Docker Volume]
    Tor2 <-->|Persistent Data| Volume
    TorN <-->|Persistent Data| Volume
```

## Components

- **Base Image**: Alpine Linux 3.20.3
- **Tor**: Multiple instances of the Onion routing network for secure internet access
- **HAProxy**: Load balancer to distribute traffic across Tor instances
- **Privoxy**: Non-caching web proxy with advanced filtering capabilities
- **gosu**: Lightweight tool to step down from root and run processes as non-privileged users
- **Persistent Volume**: For storing Tor data across container restarts

## Usage

To run the container with default settings and Tor data persistence:

```bash
docker compose up -d
```

This command will create a Docker volume named `tor-data` to store Tor's data persistently.

To use the proxy:

```bash
curl --proxy 127.0.0.1:8118 https://example.com
```

## Configuration

The container is configured using environment variables. These can be set in the `.env` file or passed directly to the container. See `.env.example` for available configuration options.

### Dockerfile

The Dockerfile specifies the following:

- Base image: Alpine 3.20.3
- Exposed ports: 8118 and 8050
- Installed packages: privoxy, tor, gosu, haproxy
- Copies entrypoint.sh script and haproxy.cfg
- Sets default environment variables for Privoxy, Tor, and HAProxy configuration
- ENTRYPOINT: /entrypoint.sh

### entrypoint.sh

The entrypoint script handles the following:

- Generates Tor, Privoxy, and HAProxy configuration files based on environment variables
- Sets correct permissions for Tor and Privoxy directories
- Starts multiple Tor instances, HAProxy, and Privoxy services using gosu for privilege de-escalation

gosu is used to run Tor and Privoxy as their respective non-root users:

```sh
for i in $(seq 0 $((NUM_TOR_INSTANCES - 1))); do
    gosu tor tor -f /etc/tor/torrc_$i &
done

haproxy -f /etc/haproxy/haproxy.cfg &

exec gosu privoxy privoxy --no-daemon /etc/privoxy/config
```

This ensures that the services run with the least privileges necessary, enhancing security.

### Privoxy

- **Config file**: Dynamically generated based on environment variables
- **Listen address**: Configurable via `PRIVOXY_LISTEN_ADDRESS`
- **Forward to HAProxy**: Configured to forward to HAProxy on port 8050

### HAProxy

- **Config file**: Dynamically generated based on the number of Tor instances
- **Frontend**: Listens on port 8050
- **Backend**: Roundrobin load balancing between Tor instances

### Tor

- **Config files**: Dynamically generated for each instance based on environment variables
- **SOCKS ports**: Automatically assigned (9050, 9051, 9052, etc.)
- **Data Directory**: Persistent storage in `/var/lib/tor/{instance_number}`, mapped to a Docker volume

## Exposed Ports

- 8118: Privoxy HTTP(S) proxy
- 8050: HAProxy SOCKS5 proxy (load balances to multiple Tor instances)

## Tor Data Persistence

Tor data for all instances is stored in a Docker volume named `tor-data`. This ensures that Tor's state, including its entry guards and other critical information, is preserved across container restarts.

To manage the persistent Tor data:

- **View volume information**: `docker volume inspect multi-tor-proxy_tor-data`
- **Backup the data**: `docker run --rm -v tor-data:/data -v /path/on/host:/backup alpine tar cvf /backup/tor-data.tar /data`
- **Restore from backup**: `docker run --rm -v tor-data:/data -v /path/on/host:/backup alpine sh -c "cd /data && tar xvf /backup/tor-data.tar --strip 1"`

## Building

To build the image yourself:

```bash
docker build -t multi-tor-proxy .
```

## Security Considerations

This project uses gosu to enhance security by running Tor and Privoxy as non-root users. This follows the principle of least privilege, reducing the potential impact of any security vulnerabilities in these services. The use of multiple Tor instances with HAProxy load balancing improves both performance and anonymity.

## License

This project is licensed under the MIT license. Refer to the LICENSE file in the repository for full details.
