# =======================
# Stage 1: Build Unbound
# =======================
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# 安装构建依赖
RUN apt update && \
    apt install -y \
    build-essential \
    autoconf \
    libtool \
    pkg-config \
    git \
    curl \
    ca-certificates \
    libssl-dev \
    libevent-dev \
    libnghttp2-dev \
    libprotobuf-c-dev \
    protobuf-c-compiler \
    cmake \
    libev-dev \
    libc-ares-dev \
    libexpat1-dev \
    python3 \
    python3-pip \
    python3-setuptools

# 构建 sfparse（nghttp3 的依赖）
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/sfparse.git
WORKDIR /build/sfparse
RUN autoreconf -i && ./configure --prefix=/usr && make -j$(nproc) && make install

# 构建 nghttp3
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git
WORKDIR /build/nghttp3
RUN autoreconf -i && ./configure --prefix=/usr && make -j$(nproc) && make install

# 构建 ngtcp2
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git
WORKDIR /build/ngtcp2
RUN autoreconf -i && ./configure --prefix=/usr && make -j$(nproc) && make install

# 构建 Unbound
WORKDIR /build
RUN git clone --depth=1 https://github.com/NLnetLabs/unbound.git
WORKDIR /build/unbound
RUN ./autogen.sh && \
    ./configure \
        --prefix=/usr \
        --with-ssl \
        --with-libevent \
        --with-libnghttp2 \
        --with-libngtcp2 \
        --with-libnghttp3 \
        --with-libev \
        --with-pthreads \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-subnet \
        --enable-tfo-client \
        --enable-tfo-server && \
    make -j$(nproc) && make install

# =======================
# Stage 2: Runtime image
# =======================
FROM alpine:3.19

# 安装运行时依赖（注意：libssl3 替代了过时的 libssl1.1）
RUN apk add --no-cache libssl3 libevent libcap bash

# 拷贝编译好的 Unbound
COPY --from=builder /usr /usr

# 创建默认配置目录（可选）
RUN mkdir -p /etc/unbound

# 设置默认入口
ENTRYPOINT ["unbound"]
