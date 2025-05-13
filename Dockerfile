# ==== Stage 1: Build environment ====
FROM ubuntu:22.04 AS builder

# 安装依赖
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
    c-ares-dev \
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

# 构建 nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && make install

# 构建 ngtcp2
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr --with-openssl --enable-lib-only && \
    make -j$(nproc) && make install

# 构建 Unbound（开启 DoQ 支持）
RUN git clone --branch release-1.19.3 https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    autoreconf -i && \
    ./configure \
      --prefix=/usr \
      --with-libevent \
      --with-ssl \
      --enable-dnscrypt \
      --enable-subnet \
      --enable-dnstap \
      --enable-tfo-client \
      --enable-tfo-server \
      --enable-pthreads \
      --enable-ecdsa \
      --enable-ed25519 \
      --enable-eddsa \
      --enable-dns-over-quic \
      --with-nghttp3=/usr \
      --with-ngtcp2=/usr && \
    make -j$(nproc) && make install

# ==== Stage 2: Minimal runtime image ====
FROM alpine:3.21 AS runtime

# 安装运行时依赖
RUN apk add --no-cache libevent openssl

# 复制构建产物
COPY --from=builder /usr/sbin/unbound /usr/sbin/unbound
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
COPY --from=builder /usr/share/unbound /usr/share/unbound

# 配置文件目录
VOLUME /etc/unbound

# 默认执行
CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
