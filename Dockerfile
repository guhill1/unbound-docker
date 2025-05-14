# Stage 1: Build everything
FROM alpine:3.19 AS builder

RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    pkgconfig \
    git \
    wget \
    curl \
    libevent-dev \
    libexpat-dev \
    libsodium-dev \
    linux-headers \
    bash \
    cmake

WORKDIR /build

# Build sfparse
RUN git clone https://github.com/h2o/sfparse.git && \
    cd sfparse && \
    cmake -S . -B build && \
    cmake --build build && \
    cmake --install build --prefix /usr/local

ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# Build OpenSSL (quictls version, supports QUIC)
RUN git clone --depth=1 -b OpenSSL_1_1_1q+quic https://github.com/quictls/openssl.git && \
    cd openssl && \
    ./config enable-tls1_3 no-shared --prefix=/usr/local && \
    make -j$(nproc) && make install_sw

# Build nghttp3
RUN git clone https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install

# Build ngtcp2
RUN git clone https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure \
        --prefix=/usr/local \
        --with-openssl=/usr/local \
        --with-nghttp3=/usr/local && \
    make -j$(nproc) && make install

# Build Unbound with QUIC
RUN git clone https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    git checkout release-1.19.3 && \
    ./autogen.sh && \
    ./configure \
        --enable-dns-over-tls \
        --enable-dns-over-https \
        --enable-dnscrypt \
        --enable-ecdsa \
        --enable-event-api \
        --enable-subnet \
        --with-libevent \
        --with-ssl=/usr/local && \
    make -j$(nproc) && make install

# Stage 2: Runtime
FROM alpine:3.19

RUN apk add --no-cache libevent libgcc libsodium expat

COPY --from=builder /usr/local /usr/local

ENTRYPOINT ["/usr/local/sbin/unbound"]
CMD ["-d"]
