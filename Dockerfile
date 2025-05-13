# 使用 Ubuntu 作为基础镜像
FROM ubuntu:22.04

# 设置时区和非交互模式
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# 更新和安装必要的依赖
RUN echo "Updating and installing dependencies..." && apt-get update && apt-get install -y \
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

# 克隆并构建 nghttp3
RUN echo "Cloning nghttp3 repository..." && \
    git clone --depth 1 https://github.com/ngtcp2/nghttp3.git /build/nghttp3 && \
    cd /build/nghttp3 && \
    git checkout master && \
    echo "Running cmake for nghttp3..." && cmake . && \
    echo "Running make for nghttp3..." && make -j$(nproc) && \
    echo "Installing nghttp3..." && make install && \
    echo "nghttp3 installation complete"

# 克隆并构建 ngtcp2
RUN echo "Cloning ngtcp2 repository..." && \
    git clone https://github.com/ngtcp2/ngtcp2.git /build/ngtcp2 && \
    cd /build/ngtcp2 && \
    echo "Running cmake for ngtcp2..." && cmake . && \
    echo "Running make for ngtcp2..." && make -j$(nproc) && \
    echo "Installing ngtcp2..." && make install && \
    echo "ngtcp2 installation complete"

# 创建目录并下载 sfparse 文件
RUN echo "Creating sfparse directory..." && \
    mkdir -p /usr/include/sfparse && \
    echo "Downloading sfparse.c..." && \
    wget https://raw.githubusercontent.com/ngtcp2/sfparse/main/sfparse.c -O /usr/include/sfparse/sfparse.c && \
    echo "Downloading sfparse.h..." && \
    wget https://raw.githubusercontent.com/ngtcp2/sfparse/main/sfparse.h -O /usr/include/sfparse/sfparse.h && \
    echo "sfparse files downloaded"

# 编译和安装 Unbound
WORKDIR /build/unbound
RUN echo "Starting Unbound build..." && \
    ./autogen.sh && \
    echo "Configuring Unbound..." && \
    ./configure --enable-dns-over-https --enable-dns-over-quad9 --enable-dns-over-quic --with-ssl-dir=/usr/local/ssl && \
    echo "Running make for Unbound..." && \
    make -j$(nproc) && \
    echo "Installing Unbound..." && \
    make install && \
    echo "Unbound installation complete"

# 暴露 Unbound 的默认端口
EXPOSE 53/tcp 53/udp

# 启动 Unbound
CMD echo "Starting Unbound..." && /usr/local/sbin/unbound -d -v
