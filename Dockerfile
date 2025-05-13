# 使用 Ubuntu 作为基础镜像
FROM ubuntu:22.04

# 设置时区和非交互模式
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# 更新和安装必要的依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    wget \
    git \
    libssl-dev \
    libevent-dev \
    pkg-config \
    libgeoip-dev \
    python3 \
    python3-pip \
    libnghttp2-dev \
    libprotobuf-c-dev \
    libgmp-dev \
    autoconf \
    automake \
    libtool \
    libcap-dev \
    libssl-dev \
    curl \
    ca-certificates \
    libnghttp3-dev \
    libngtcp2-dev \
    libfstrm-dev \
    libcap-ng-dev \
    liblzma-dev \
    libjemalloc-dev \
    libunwind-dev \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /build

# 克隆 Unbound 源代码
RUN git clone https://github.com/NLnetLabs/unbound.git

# 克隆并构建 nghttp3
RUN git clone https://github.com/ngtcp2/nghttp3.git /build/nghttp3 && \
    cd /build/nghttp3 && \
    cmake . && make -j$(nproc) && make install

# 克隆并构建 ngtcp2
RUN git clone https://github.com/ngtcp2/ngtcp2.git /build/ngtcp2 && \
    cd /build/ngtcp2 && \
    cmake . && make -j$(nproc) && make install

# 创建目录并下载 sfparse 文件
RUN mkdir -p /usr/include/sfparse && \
    wget https://raw.githubusercontent.com/ngtcp2/sfparse/main/sfparse.c -O /usr/include/sfparse/sfparse.c && \
    wget https://raw.githubusercontent.com/ngtcp2/sfparse/main/sfparse.h -O /usr/include/sfparse/sfparse.h

# 编译和安装 Unbound
WORKDIR /build/unbound
RUN ./autogen.sh && \
    ./configure --enable-dns-over-https --enable-dns-over-quad9 --enable-dns-over-quic --with-ssl-dir=/usr/local/ssl && \
    make -j$(nproc) && \
    make install

# 暴露 Unbound 的默认端口
EXPOSE 53/tcp 53/udp

# 启动 Unbound
CMD ["/usr/local/sbin/unbound", "-d", "-v"]
