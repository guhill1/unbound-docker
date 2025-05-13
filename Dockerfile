# -------- STAGE 1: Build dependencies --------
FROM alpine:latest AS builder

RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    git \
    openssl-dev \
    libev-dev \
    libevent-dev \
    c-ares-dev \
    libcap-dev \
    linux-headers \
    zlib-dev \
    cmake \
    gnutls-dev \
    pkgconfig \
    bash \
    curl \
    expat-dev

# -------- Build sfparse --------
WORKDIR /build/sfparse
RUN git clone https://github.com/ngtcp2/sfparse . \
    && autoreconf -i \
    && ./configure --prefix=/usr \
    && make -j$(nproc) \
    && make install \
    && mkdir -p /usr/include/sfparse \
    && cp sfparse.h /usr/include/sfparse/

# -------- Build nghttp3 --------
WORKDIR /build/nghttp3
RUN git clone https://github.com/ngtcp2/nghttp3 . \
    && autoreconf -i \
    && ./configure --prefix=/usr \
    && make -j$(nproc) \
    && make install

# -------- Build ngtcp2 --------
WORKDIR /build/ngtcp2
RUN git clone https://github.com/ngtcp2/ngtcp2 . \
    && autoreconf -i \
    && ./configure --prefix=/usr --enable-lib-only \
    && make -j$(nproc) \
    && make install

# -------- Build unbound --------
WORKDIR /build/unbound
RUN git clone https://github.com/NLnetLabs/unbound . \
    && cd unbound \
    && git checkout release-1.20.0 \
    && autoreconf -fi \
    && ./configure --prefix=/opt/unbound \
        --enable-dns-over-quic \
        --with-libngtcp2=/usr \
        --with-libnghttp3=/usr \
    && make -j$(nproc) \
    && make install

# -------- STAGE 2: Create final image --------
FROM alpine:latest

RUN apk add --no-cache \
    libevent \
    libcap \
    ca-certificates \
    libcrypto3 \
    libssl3

COPY --from=builder /opt/unbound /opt/unbound
COPY --from=builder /usr/lib /usr/lib
COPY --from=builder /usr/include /usr/include

ENV PATH="/opt/unbound/sbin:$PATH"

ENTRYPOINT ["unbound"]
CMD ["-d", "-c", "/opt/unbound/etc/unbound/unbound.conf"]
