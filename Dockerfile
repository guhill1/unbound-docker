# 使用 Ubuntu 作为基础镜像
FROM ubuntu:22.04

# 安装编译工具和依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    git \
    curl \
    gcc \
    g++ \
    make \
    bash \
    libssl-dev \
    libevent-dev \
    libcap-dev \
    && rm -rf /var/lib/apt/lists/*

# 安装必要的工具和库，确保 nghttp3 构建依赖正确
RUN apt-get update && apt-get install -y \
    libprotobuf-c-dev \
    protobuf-c-compiler \
    libnghttp2-dev \
    libc-ares-dev \
    libz-dev \
    && rm -rf /var/lib/apt/lists/*

# 构建 sfparse
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/sfparse.git
WORKDIR /build/sfparse
RUN autoreconf -i \
    && ./configure --prefix=/usr \
    && make -j$(nproc) \
    && make install

# 构建 nghttp3
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git
WORKDIR /build/nghttp3

# 设置编译环境变量，确保 nghttp3 能找到 sfparse 的头文件
ENV CFLAGS="-I/usr/include/sfparse"
ENV LDFLAGS="-L/usr/lib"

RUN autoreconf -i \
    && ./configure --prefix=/usr \
    && make -j$(nproc) \
    && make install

# 构建 ngtcp2
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git
WORKDIR /build/ngtcp2
RUN autoreconf -i \
    && ./configure --prefix=/usr \
    && make -j$(nproc) \
    && make install

# 清理不必要的文件
RUN rm -rf /build

# 设置工作目录
WORKDIR /root
