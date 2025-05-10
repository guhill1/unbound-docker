FROM alpine:latest

RUN apk add --no-cache unbound unbound-libs

COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
