# ---------- Stage 1: Build Dependencies ----------
FROM ubuntu:22.04 as builder

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libssl-dev \
    libevent-dev \
    libexpat-dev \ 
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# ---- Build nghttp3 (with submodules) ----
RUN git clone --recursive https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    cmake . -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    make install

# ---- Build ngtcp2 ----
RUN git clone --recursive https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --enable-lib-only && \
    make -j$(nproc) && \
    make install

# ---- Build Unbound ----
RUN curl -LO https://nlnetlabs.nl/downloads/unbound/unbound-1.20.0.tar.gz && \
    tar xzf unbound-1.20.0.tar.gz && \
    cd unbound-1.20.0 && \
    ./configure --with-ssl --with-libevent --enable-dnscrypt --enable-dns-over-tls --enable-dns-over-https --enable-dns-over-quic && \
    make -j$(nproc) && \
    make install

# ---------- Stage 2: Minimal Runtime ----------
FROM alpine:3.20

RUN apk add --no-cache libevent openssl

COPY --from=builder /usr/local /usr/local

# 添加默认配置文件
COPY --from=builder /build/unbound-1.20.0/doc/example.conf /etc/unbound/unbound.conf

# 默认入口
CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
