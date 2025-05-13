# 使用官方的 Ubuntu 基础镜像
FROM ubuntu:20.04

# 设置环境变量，防止交互式安装
ENV DEBIAN_FRONTEND=noninteractive

# 更新并安装必要的依赖
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
    linux-headers-$(uname -r) \
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

# 安装其他必要的依赖（如 OpenSSL、libevent 等）
RUN pip3 install --upgrade pip

# 创建工作目录
WORKDIR /build

# 克隆并构建 nghttp3
RUN echo "Cloning nghttp3 repository..." && \
    git clone --depth 1 https://github.com/ngtcp2/nghttp3.git /build/nghttp3 && \
    cd /build/nghttp3 && \
    git branch -r && \
    git checkout main && \
    echo "Running cmake for nghttp3..." && \
    cmake . -DCMAKE_BUILD_TYPE=Release && \
    echo "Running make for nghttp3..." && \
    make -j$(nproc) && \
    echo "Installing nghttp3..." && \
    make install && \
    echo "nghttp3 installation complete"

# 克隆并构建 ngtcp2
RUN echo "Cloning ngtcp2 repository..." && \
    git clone --depth 1 https://github.com/ngtcp2/ngtcp2.git /build/ngtcp2 && \
    cd /build/ngtcp2 && \
    git branch -r && \
    git checkout main && \
    echo "Running cmake for ngtcp2..." && \
    cmake . -DCMAKE_BUILD_TYPE=Release && \
    echo "Running make for ngtcp2..." && \
    make -j$(nproc) && \
    echo "Installing ngtcp2..." && \
    make install && \
    echo "ngtcp2 installation complete"

# 克隆并构建 Unbound
RUN echo "Cloning Unbound repository..." && \
    git clone --depth 1 https://github.com/NLnetLabs/unbound.git /build/unbound && \
    cd /build/unbound && \
    git checkout main && \
    echo "Running cmake for Unbound..." && \
    cmake . -DCMAKE_BUILD_TYPE=Release && \
    echo "Running make for Unbound..." && \
    make -j$(nproc) && \
    echo "Installing Unbound..." && \
    make install && \
    echo "Unbound installation complete"

# 设置 Unbound 配置（跳过此部分，根据需要添加）
# RUN mkdir -p /etc/unbound && ...

# 清理构建过程中生成的文件
RUN rm -rf /build/nghttp3 /build/ngtcp2 /build/unbound

# 设置容器启动命令
CMD ["unbound", "-d"]
