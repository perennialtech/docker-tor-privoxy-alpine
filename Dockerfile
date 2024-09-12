FROM alpine:3.20.3

EXPOSE 8118 8050

ARG PRIVOXY_VERSION=3.0.34-r2
ARG TOR_VERSION=0.4.8.12-r0
ARG GOSU_VERSION=1.17-r5
ARG HAPROXY_VERSION=2.8.10-r0

RUN echo "@edge http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    apk --no-cache add \
    privoxy=${PRIVOXY_VERSION} \
    tor=${TOR_VERSION} \
    haproxy=${HAPROXY_VERSION} \
    gosu@edge=${GOSU_VERSION}

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

HEALTHCHECK --interval=60s --timeout=15s --start-period=20s \
  CMD nc -z 127.0.0.1 8118 || exit 1
