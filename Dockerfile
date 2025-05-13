FROM alpine:edge AS builder

# 安装构建依赖
RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    git \
    openssl-dev \
    libevent-dev \
    ca-certificates \
    linux-headers \
    doxygen

# === 构建 sfparse ===
WORKDIR /build/sfparse
RUN git clone https://github.com/ngtcp2/sfparse . \
    && autoreconf -i \
    && ./configure --prefix=/usr \
    && make -j$(nproc) \
    && make install \
    # ✅ 解决 nghttp3 找不到 sfparse/sfparse.h 的问题
    && mkdir -p /usr/include/sfparse \
    && cp include/sfparse.h /usr/include/sfparse/

# === 构建 nghttp3 ===
WORKDIR /build/nghttp3
RUN git clone https://github.com/ngtcp2/nghttp3 . \
    && autoreconf -i \
    && ./configure --prefix=/usr \
    && make -j$(nproc) \
    && make install

# === 继续后续构建步骤，例如 ngtcp2, unbound 等 ===
# 你可以在这里继续构建 ngtcp2、quiche、unbound 等，
# 因为 nghttp3 已经能正确编译通过了。

# 示例占位（根据需要添加）
# WORKDIR /build/ngtcp2
# RUN git clone https://github.com/ngtcp2/ngtcp2 . && ...
