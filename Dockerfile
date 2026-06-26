# 3.24.1
FROM alpine@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

ARG CURL_VERSION=8.20.0-r1
ARG HAPROXY_VERSION=3.4.0-r0
ARG SU_EXEC_VERSION=0.3-r0
ARG TOR_VERSION=0.4.9.10-r0

# Fixed high UIDs/GIDs keep service ownership predictable across platforms.
RUN addgroup -S -g 10002 haproxy && \
    adduser -S -D -H -u 10002 -G haproxy haproxy && \
    addgroup -S -g 10003 tor && \
    adduser -S -D -H -u 10003 -G tor tor

RUN apk --no-cache add \
    curl=${CURL_VERSION} \
    haproxy=${HAPROXY_VERSION} \
    su-exec=${SU_EXEC_VERSION} \
    tor=${TOR_VERSION}

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]

HEALTHCHECK --interval=60s --timeout=30s --start-period=180s --retries=3 \
  CMD curl --fail --silent --show-error --max-time 20 --proxy http://127.0.0.1:8118 https://check.torproject.org/api/ip | grep -q '"IsTor"[[:space:]]*:[[:space:]]*true' || exit 1
