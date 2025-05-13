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
    libevent-dev \
    libexpat-dev \
    libsodium-dev \
    ca-certificates \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# 安装 OpenSSL 3.x 版本
RUN wget https://www.openssl.org/source/openssl-3.0.8.tar.gz && \
    tar -xvzf openssl-3.0.8.tar.gz && \
    cd openssl-3.0.8 && \
    ./config --prefix=/usr/local --openssldir=/usr/local/openssl && \
    make -j$(nproc) && \
    make install

# 更新环境变量，确保使用新安装的 OpenSSL
ENV PATH="/usr/local/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

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
    ./configure --enable-lib-only --with-openssl --with-libev --with-nghttp3 && \
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
