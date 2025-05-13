# 使用官方 Ubuntu 镜像作为基础镜像
FROM ubuntu:20.04

# 设置环境变量避免交互提示
ENV DEBIAN_FRONTEND=noninteractive

# 安装必要的依赖包
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    cmake \
    git \
    wget \
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
    libjemalloc-dev \
    libunwind-dev \
    libsodium-dev \
    lsb-release \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 安装 CMake 3.20 或更高版本
RUN echo "deb https://apt.kitware.com/ubuntu/ $(lsb_release -c | awk '{print $2}') main" | tee /etc/apt/sources.list.d/kitware.list \
    && curl -fsSL https://apt.kitware.com/keys/kitware-archive.sh | bash \
    && apt-get update && apt-get install -y cmake \
    && cmake --version

# 克隆并构建 nghttp3
RUN echo "Cloning nghttp3 repository..." && \
    git clone --depth 1 https://github.com/ngtcp2/nghttp3.git /build/nghttp3 && \
    cd /build/nghttp3 && \
    git checkout main && \
    echo "Running cmake for nghttp3..." && \
    cmake . -DCMAKE_BUILD_TYPE=Release && \
    echo "Running make for nghttp3..." && \
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
    echo "Running make for ngtcp2..." && \
    make -j$(nproc) && \
    make install && \
    echo "ngtcp2 installation complete"

# 克隆并构建 Unbound
RUN echo "Cloning Unbound repository..." && \
    git clone --depth 1 https://github.com/NLnetLabs/unbound.git /build/unbound && \
    cd /build/unbound && \
    echo "Running cmake for Unbound..." && \
    cmake . -DCMAKE_BUILD_TYPE=Release && \
    echo "Running make for Unbound..." && \
    make -j$(nproc) && \
    make install && \
    echo "Unbound installation complete"

# 清理临时文件，减少镜像体积
RUN rm -rf /build && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /etc/unbound

# 最后执行 Unbound 或其他命令（根据需要修改）
CMD ["unbound"]
