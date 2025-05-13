# ==== 构建阶段 ====
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    ca-certificates \
    git \
    curl \
    libssl-dev \
    libevent-dev \
    libcap-dev \
    bash \
    libc-ares-dev \
    libnghttp2-dev \
    libprotobuf-c-dev \
    protobuf-c-compiler \
    libev-dev \
    libyaml-dev \
    libexpat1-dev \
    doxygen \
    python3-sphinx \
    cmake \
    ninja-build \
    clang \
    zlib1g-dev \
    wget \
    libuv1-dev \
    linux-headers-generic \
    && rm -rf /var/lib/apt/lists/*

# 构建 sfparse（nghttp3 依赖）
RUN git clone --depth=1 https://github.com/ngtcp2/sfparse.git
WORKDIR /sfparse
RUN autoreconf -i && ./configure --prefix=/usr && make -j$(nproc) && make install

# 构建 nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git
WORKDIR /nghttp3
RUN autoreconf -i && ./configure --prefix=/usr && make -j$(nproc) && make install

# 构建 ngtcp2
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git
WORKDIR /ngtcp2
RUN autoreconf -i && ./configure --prefix=/usr --enable-lib-only && make -j$(nproc) && make install

# 构建 Unbound with QUIC support
RUN git clone --depth=1 https://github.com/NLnetLabs/unbound.git
WORKDIR /unbound
RUN autoreconf -i && ./configure --prefix=/usr --enable-dns-over-quic --with-ssl --with-libevent && make -j$(nproc) && make install

# ==== 运行阶段 ====
FROM alpine:latest

RUN apk --no-cache add libssl3 libevent

COPY --from=builder /usr /usr

ENTRYPOINT ["unbound"]
