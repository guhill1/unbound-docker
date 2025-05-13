# 使用基础镜像（Ubuntu 22.04）
FROM ubuntu:22.04 AS builder

# 设置工作目录
WORKDIR /build

# 安装构建工具和依赖项
RUN apt-get update && apt-get install -y \
    # 基础构建工具
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    ca-certificates \
    git \
    curl \
    wget \
    bash \
    # 开发库
    libssl-dev \
    libevent-dev \
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
    libuv1-dev \
    linux-headers-generic && \
    rm -rf /var/lib/apt/lists/*

# 克隆并构建 nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && make install

# 克隆并构建 nghttp2
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp2.git && \
    cd nghttp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && make install

# 克隆并构建 ngtcp2
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr --with-libnghttp3=/usr --with-libnghttp2=/usr && \
    make -j$(nproc) && make install

# 克隆并构建支持 QUIC 的 Unbound
RUN git clone --depth=1 https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    git submodule update --init && \
    autoreconf -fi && \
    ./configure --prefix=/usr \
        --enable-subnet \
        --enable-tfo-client \
        --enable-tfo-server \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-event-api \
        --enable-cachedb \
        --enable-pthreads \
        --enable-systemd \
        --with-libngtcp2=/usr \
        --with-libnghttp3=/usr \
        --with-libnghttp2=/usr && \
    make -j$(nproc) && make install

# 运行阶段，构建瘦镜像（可选）
FROM ubuntu:22.04 AS runtime

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libevent-dev \
    libc-ares-dev \
    libnghttp2-dev \
    libprotobuf-c-dev \
    protobuf-c-compiler \
    libev-dev \
    libyaml-dev \
    libexpat1-dev \
    zlib1g \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 拷贝构建好的 Unbound 到运行镜像
COPY --from=builder /usr /usr

# 设置默认启动命令（可替换）
ENTRYPOINT ["unbound"]
CMD ["-d", "-v"]
