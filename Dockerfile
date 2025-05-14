# ---------- Builder stage ----------
FROM alpine:3.19 AS builder

RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    git \
    wget \
    curl \
    cmake \
    perl \
    linux-headers \
    libevent-dev \
    expat-dev \
    libsodium-dev \
    pkgconfig \
    python3 \
    bash

WORKDIR /build

# ---------- Build OpenSSL with QUIC support (quictls) ----------
WORKDIR /build/openssl
RUN git clone --branch OpenSSL_1_1_1w+quic --depth=1 https://github.com/quictls/openssl.git . && \
    ./config --prefix=/usr/local/openssl --libdir=lib no-shared enable-tls1_3 && \
    make -j$(nproc) && \
    make install_sw

ENV PATH="/usr/local/openssl/bin:$PATH"
ENV PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig"
ENV LD_LIBRARY_PATH="/usr/local/openssl/lib"

# ---------- Build nghttp3 (v1.9.0) ----------
WORKDIR /build/nghttp3
RUN git clone --branch v1.9.0 https://github.com/ngtcp2/nghttp3.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j$(nproc) && \
    make install

# ---------- Build ngtcp2 (v1.6.0) ----------
WORKDIR /build/ngtcp2
RUN git clone --branch v1.6.0 https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
        --with-openssl=/usr/local/openssl \
        --with-libnghttp3=/usr/local \
        PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" && \
    make -j$(nproc) && \
    make install

# ---------- Build Unbound (v1.19.3) ----------
WORKDIR /build/unbound
RUN git clone --branch release-1.19.3 https://github.com/NLnetLabs/unbound.git . && \
    ./autogen.sh && \
    ./configure --prefix=/usr/local \
        --with-libevent \
        --with-libnghttp3=/usr/local \
        --with-libngtcp2=/usr/local \
        --with-ssl=/usr/local/openssl && \
    make -j$(nproc) && \
    make install

# ---------- Final stage ----------
FROM alpine:3.19

RUN apk add --no-cache libevent libsodium expat

COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/local/openssl /usr/local/openssl

ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/local/openssl/lib"

ENTRYPOINT ["/usr/local/sbin/unbound"]
