# ===============================
# 第一阶段：构建依赖和 Unbound
# ===============================
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# 安装构建依赖
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

WORKDIR /build

# 编译 nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && make install

# 编译 ngtcp2
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr --with-openssl && \
    make -j$(nproc) && make install

# 获取并编译 unbound（需要手动替换你要使用的版本）
ENV UNBOUND_VERSION=1.20.0
RUN wget https://www.nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz && \
    tar xzf unbound-${UNBOUND_VERSION}.tar.gz && \
    cd unbound-${UNBOUND_VERSION} && \
    ./configure --prefix=/opt/unbound \
        --enable-subnet \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-tfo-client \
        --enable-tfo-server \
        --enable-ipsecmod \
        --enable-ecdsa \
        --enable-ed25519 \
        --enable-ed448 \
        --with-libevent \
        --with-ssl \
        --with-libngtcp2 \
        --with-libnghttp3 \
        --enable-dns-over-quic \
        && make -j$(nproc) && make install

# ===============================
# 第二阶段：精简运行环境
# ===============================
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    libevent-2.1-7 \
    libssl3 \
    libc-ares2 \
    libprotobuf-c1 \
    libev4 \
    libyaml-0-2 \
    libexpat1 \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

# 复制构建好的 unbound
COPY --from=builder /opt/unbound /opt/unbound

# 设置默认执行命令
ENTRYPOINT ["/opt/unbound/sbin/unbound"]
CMD ["-d"]
