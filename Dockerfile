# 使用 Ubuntu 20.04 作为基础镜像
FROM ubuntu:20.04

# 设置环境变量，避免某些交互式提示
ENV DEBIAN_FRONTEND=noninteractive

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
    autoconf \
    automake \
    libtool \
    libcap-dev \
    curl \
    ca-certificates \
    libfstrm-dev \
    libcap-ng-dev \
    liblzma-dev \
    libjemalloc-dev \
    libunwind-dev \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

# 克隆并构建 nghttp3
RUN echo "Cloning nghttp3 repository..." && \
    git clone --depth 1 https://github.com/ngtcp2/nghttp3.git /build/nghttp3 && \
    cd /build/nghttp3 && \
    git checkout main && \
    echo "Running cmake for nghttp3..." && \
    cmake . -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    make install && \
    echo "nghttp3 installation complete"

# 克隆并构建 ngtcp2
RUN echo "Cloning ngtcp2 repository..." && \
    git clone --depth 1 https://github.com/ngtcp2/ngtcp2.git /build/ngtcp2 && \
    cd /build/ngtcp2 && \
    git checkout main && \
    echo "Running cmake for ngtcp2..." && \
    cmake . -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    make install && \
    echo "ngtcp2 installation complete"

# 克隆并构建 Unbound
RUN echo "Cloning Unbound repository..." && \
    git clone --depth 1 https://github.com/NLnetLabs/unbound.git /build/unbound && \
    cd /build/unbound && \
    echo "Running cmake for Unbound..." && \
    cmake . -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    make install && \
    echo "Unbound installation complete"

# 创建 sfparse 目录并安装
RUN mkdir -p /usr/include/sfparse && \
    wget https://raw.githubusercontent.com/ngtcp2/sfparse/main/sfparse.c -O /usr/include/sfparse/sfparse.c && \
    wget https://raw.githubusercontent.com/ngtcp2/sfparse/main/sfparse.h -O /usr/include/sfparse/sfparse.h

# 配置 Unbound
RUN mkdir -p /etc/unbound
# 假设你会根据自己的需求进一步配置 Unbound

# 清理缓存和临时文件
RUN rm -rf /build/*

# 设置默认命令（可以根据需要调整）
CMD ["unbound", "-d"]
