# 使用 Ubuntu 作为基础镜像
FROM ubuntu:22.04 AS builder

# 设置环境变量以确保在构建过程中不出现交互提示
ENV DEBIAN_FRONTEND=noninteractive

# 安装构建所需的依赖
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
    libsf-dev \ # 假设存在 libsf-dev 作为依赖，或者你可以手动获取 sfparse 库
    && rm -rf /var/lib/apt/lists/*

# 克隆并构建 nghttp2
RUN git clone --depth=1 https://github.com/nghttp2/nghttp2.git && \
    cd nghttp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && \
    make install

# 克隆并构建 ngtcp2
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && \
    make install

# 克隆并构建 nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && \
    make install

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    libevent \
    libssl1.1 \
    libcap2 \
    && rm -rf /var/lib/apt/lists/*

# 复制构建好的二进制文件和其他必要文件到运行时镜像
FROM ubuntu:22.04 AS runtime

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    libevent \
    libssl1.1 \
    libcap2 \
    && rm -rf /var/lib/apt/lists/*

# 复制文件
COPY --from=builder /usr/local /usr/local

# 默认命令
CMD ["/bin/bash"]
