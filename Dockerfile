# 使用最新的 Alpine 镜像
FROM alpine:latest

# 安装构建所需的依赖项
RUN apk add --no-cache \
    git \
    autoconf \
    automake \
    libtool \
    gcc \
    g++ \
    make \
    bash \
    libevent-dev \
    openssl-dev \
    nghttp3-dev \
    ngtcp2-dev \
    flex \
    bison \
    expat-dev

# 克隆 Unbound 源码并切换到指定版本
RUN git clone https://github.com/NLnetLabs/unbound.git /build/unbound && \
    cd /build/unbound && \
    git checkout release-1.19.3

# 设置工作目录
WORKDIR /build/unbound

# 运行 autogen.sh（如果有），然后配置（注意启用了 --enable-quic）
RUN [ -f autogen.sh ] && chmod +x autogen.sh && ./autogen.sh || true && \
    ./configure \
        --enable-dns-over-quic \
        --enable-quic \
        --enable-event-api \
        --with-libevent \
        --with-ssl \
        --with-libnghttp3 \
        --with-libngtcp2 \
        --disable-shared

# 编译并安装
RUN make -j$(nproc) && make install

# 清理构建文件
RUN cd / && rm -rf /build/unbound

# 复制配置文件和证书
COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

# 设置默认命令运行 Unbound
CMD ["unbound", "-d]()
