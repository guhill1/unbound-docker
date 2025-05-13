# 使用合适的基础镜像
FROM ubuntu:20.04

# 设置环境变量，避免交互提示
ENV DEBIAN_FRONTEND=noninteractive

# 更新并安装依赖项
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    cmake \
    curl \
    pkg-config \
    libssl-dev \
    libevent-dev \
    libssl-dev \
    libnghttp2-dev \
    liblzma-dev \
    libudns-dev \
    && rm -rf /var/lib/apt/lists/*

# 克隆并构建 sfparse
RUN echo "Cloning sfparse repository..." && \
    git clone https://github.com/ngtcp2/sfparse.git /build/sfparse && \
    cd /build/sfparse && \
    git checkout main && \
    echo "sfparse repository cloned successfully"

# 克隆并构建 nghttp3
RUN echo "Cloning nghttp3 repository..." && \
    git clone --depth 1 https://github.com/ngtcp2/nghttp3.git /build/nghttp3 && \
    cd /build/nghttp3 && \
    git checkout main && \
    echo "Running cmake for nghttp3..." && \
    cmake . -DCMAKE_BUILD_TYPE=Release -DSFPARSE_DIR=/build/sfparse && \
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
    cmake . -DCMAKE_BUILD_TYPE=Release -DNGTCP2_USE_QUICHE=ON && \
    echo "Running make for ngtcp2..." && \
    make -j$(nproc) && \
    make install && \
    echo "ngtcp2 installation complete"

# 克隆并构建 Unbound
RUN echo "Cloning Unbound repository..." && \
    git clone --depth 1 https://github.com/NLnetLabs/unbound.git /build/unbound && \
    cd /build/unbound && \
    git checkout main && \
    echo "Running cmake for Unbound..." && \
    cmake . -DCMAKE_BUILD_TYPE=Release -DENABLE_DNS_OVER_QUIC=ON -DSFPARSE_DIR=/build/sfparse && \
    echo "Running make for Unbound..." && \
    make -j$(nproc) && \
    make install && \
    echo "Unbound installation complete"

# 清理不必要的文件
RUN rm -rf /build

# 默认启动配置 (可以根据需要调整 Unbound 配置)
CMD ["unbound"]
