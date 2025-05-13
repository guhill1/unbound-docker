# syntax=docker/dockerfile:1

### ===== Stage 1: Build all dependencies =====
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libev-dev \
    libevent-dev \
    ca-certificates \
    git \
    curl \
    wget \
    cmake \
    python3 \
    doxygen \
    bison \
    flex \
    libssl-dev \
    zlib1g-dev

WORKDIR /opt

# ---------- Build sfparse ----------
RUN git clone https://github.com/ngtcp2/sfparse.git && \
    cd sfparse && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# ---------- Build nghttp3 ----------
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# ---------- Build quictls/openssl ----------
RUN git clone --depth=1 -b openssl-3.0.8+quic https://github.com/quictls/openssl.git && \
    cd openssl && \
    ./config --prefix=/usr/local --libdir=lib && \
    make -j$(nproc) && \
    make install

# ---------- Build ngtcp2 ----------
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
RUN git clone --recursive https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --enable-lib-only \
        --with-openssl=/usr/local \
        --with-nghttp3=/usr/local \
        --with-libev \
        --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# ---------- Build Unbound ----------
RUN git clone https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    git checkout release-1.20.0 && \
    ./autogen.sh && \
    ./configure --prefix=/opt/unbound \
        --with-ssl=/usr/local \
        --with-libevent \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-subnet \
        --enable-tfo-client \
        --enable-tfo-server \
        --enable-ecdsa \
        --enable-ed25519 \
        --enable-ed448 \
        --enable-quic \
        PKG_CONFIG_PATH=/usr/local/lib/pkgconfig && \
    make -j$(nproc) && \
    make install

---

### ===== Stage 2: Runtime image =====
FROM debian:bookworm-slim

RUN apt update && apt install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/unbound /opt/unbound
COPY --from=builder /usr/local/lib /usr/local/lib

ENV PATH="/opt/unbound/sbin:$PATH"

CMD ["unbound", "-d"] 
