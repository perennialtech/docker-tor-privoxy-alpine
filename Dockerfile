FROM alpine:3.20.3

EXPOSE 8118 9050

ARG PRIVOXY_VERSION=3.0.34-r2
ARG TOR_VERSION=0.4.8.12-r0
ARG GOSU_VERSION=1.17-r5

RUN echo "@edge http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    apk --no-cache add \
    privoxy=${PRIVOXY_VERSION} \
    tor=${TOR_VERSION} \
    gosu@edge=${GOSU_VERSION} && \
    mkdir -p /etc/tor /etc/privoxy /var/lib/tor && \
    chown -R 101:65533 /etc/tor /var/lib/tor && \
    chown -R 100:101 /etc/privoxy

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

HEALTHCHECK --interval=60s --timeout=15s --start-period=20s \
  CMD nc -z 127.0.0.1 8118 || exit 1
