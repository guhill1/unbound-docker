# 使用基础镜像（例如，Ubuntu 22.04）
FROM ubuntu:22.04

# 设置工作目录
WORKDIR /build

# 安装构建工具和依赖项
RUN apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    ca-certificates \
    git \
    curl \
    libssl-dev \           # 使用 libssl-dev 代替 libssl1.1
    libevent-dev \          # 使用 libevent-dev 代替 libevent
    libcap2 \               # 保持 libcap2
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
    libsf-dev \             # 保持 libsf-dev
    && rm -rf /var/lib/apt/lists/*

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
    ./configure --prefix=/usr && \
    make -j$(nproc) && make install

# 克隆并构建 nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && make install

# 编译并安装目标程序
# 例如，编译你的项目或需要的二进制文件
# RUN make your_target && make install

# 复制二进制和必要文件
# 例如，你的程序需要的文件
# COPY your_binary /usr/local/bin/

# 清理构建文件（如果需要）
# RUN rm -rf /build

# 设置默认命令
CMD ["bash"]
