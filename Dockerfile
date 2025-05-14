FROM alpine:3.19 AS builder

RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    git \
    wget \
    curl \
    openssl-dev \
    libevent-dev \
    expat-dev \
    libsodium-dev \
    pkgconfig \
    libcap \
    linux-headers \
    cmake

WORKDIR /build

# ========= 1. 编译 sfparse =========
WORKDIR /build/sfparse
RUN git clone --depth=1 https://github.com/ngtcp2/sfparse.git . && \
    make -j$(nproc) && \
    cp sfparse.h /usr/local/include/ && \
    cp sfparse.a /usr/local/lib/

# ========= 2. 编译 nghttp3 =========
WORKDIR /build/nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git . && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# ========= 3. 编译 ngtcp2 =========
WORKDIR /build/ngtcp2
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -i && \
    ./configure --prefix=/usr/local --with-libnghttp3=/usr/local --with-openssl && \
    make -j$(nproc) && \
    make install

# ========= 4. 编译 Unbound =========
WORKDIR /build/unbound
RUN git clone --branch release-1.19.3 https://github.com/NLnetLabs/unbound.git . && \
    autoreconf -i && \
    ./configure \
        --prefix=/usr/local \
        --enable-subnet \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-event-api \
        --enable-tfo-client \
        --enable-tfo-server \
        --enable-tls \
        --enable-ecdsa \
        --enable-ed25519 \
        --enable-ed448 \
        --enable-libevent \
        --enable-relro-now \
        --with-ssl=/usr && \
    make -j$(nproc) && \
    make install

# ========= 5. 精简运行环境镜像 =========
FROM alpine:3.19

RUN apk add --no-cache libevent openssl libsodium expat

COPY --from=builder /usr/local /usr/local

ENTRYPOINT ["/usr/local/sbin/unbound"]
CMD ["-d"]
