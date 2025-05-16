FROM alpine:3.21

RUN apk add --no-cache libevent libcap expat libsodium libc6-compat libbsd

COPY --from=builder /usr/local /usr/local

ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
ENV LD_PRELOAD=/lib/libbsd.so
ENV PATH=/usr/local/sbin:$PATH

EXPOSE 853/udp 853/tcp 8853/udp

ENTRYPOINT ["/usr/local/sbin/unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
