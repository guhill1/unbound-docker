# syntax=docker/dockerfile:1.4

### ----------- 第一阶段：构建支持 DoQ 的 Unbound ----------
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# 安装编译依赖
RUN apt update && apt install -y \
    build-essential \
    git \
    curl \
    cmake \
    ninja-build \
    libssl-dev \
    libevent-dev \
    libcap2 \
    bash \
    libc-ares-dev \
    libnghttp2-dev \
    libprotobuf-c-dev \
    protobuf-c-compiler \
    pkg-config \
    autoconf \
    automake \
    libtool \
    libev-dev \
    ca-certificates \
    libuv1-dev \
    libgnutls28-dev \
    linux-headers-generic && \
    rm -rf /var/lib/apt/lists/*

# 构建 nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git
WORKDIR /nghttp3
RUN cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr && \
    cmake --build build && \
    cmake --install build

# 构建 ngtcp2（lib-only）
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git
WORKDIR /ngtcp2
RUN cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
    -DENABLE_LIB_ONLY=ON && \
    cmake --build build && \
    cmake --install build

# 构建 Unbound
RUN git clone --depth=1 https://github.com/NLnetLabs/unbound.git
WORKDIR /unbound
RUN ./autogen.sh && \
    ./configure --prefix=/usr \
        --with-ssl \
        --with-libevent \
        --with-libnghttp2 \
        --with-libngtcp2 \
        --with-libnghttp3 \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-subnet \
        --enable-tfo-client \
        --enable-tfo-server \
        --enable-cachedb && \
    make -j$(nproc) && \
    make install

### ----------- 第二阶段：精简运行环境 ----------
FROM alpine:3.19

RUN apk add --no-cache libssl1.1 libevent libcap bash

COPY --from=builder /usr /usr

ENTRYPOINT ["unbound"]
