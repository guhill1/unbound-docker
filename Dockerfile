# ---------- 基础镜像 ----------
FROM alpine:3.21 AS builder

# 安装构建依赖项
RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    git \
    cmake \
    libevent-dev \
    expat-dev \
    libsodium-dev \
    libcap \
    linux-headers \
    curl \
    openssl-dev

# ---------- 构建 sfparse ----------
WORKDIR /build/sfparse
RUN git clone https://github.com/ngtcp2/sfparse.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# ---------- 构建 nghttp3 ----------
WORKDIR /build/nghttp3
RUN git clone --branch v1.9.0 https://github.com/ngtcp2/nghttp3.git . && \
    # 创建 sfparse 目录并将 sfparse.h 和 sfparse.c 拷贝到正确位置
    mkdir -p lib/sfparse && \
    cp /usr/local/src/sfparse/sfparse.c lib/sfparse/sfparse.c && \
    cp /usr/local/include/sfparse.h /build/nghttp3/lib/sfparse/sfparse.h && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j$(nproc) && make install

# ---------- 构建 ngtcp2 ----------
WORKDIR /build/ngtcp2
RUN git clone --branch v1.47.0 https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j$(nproc) && \
    make install

# ---------- 清理 ----------
FROM alpine:3.21
RUN apk add --no-cache \
    openssl \
    libsodium \
    libevent \
    expat

# 复制构建好的文件到新的镜像
COPY --from=builder /usr/local /usr/local

# 设置工作目录
WORKDIR /app

# 默认启动命令
CMD ["sh"]
