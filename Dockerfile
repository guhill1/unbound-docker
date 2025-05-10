# 使用最新的 Alpine 镜像
FROM alpine:latest

# 安装构建所需依赖
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

# 克隆 Unbound 源码
RUN git clone https://github.com/NLnetLabs/unbound.git /build/unbound && \
    cd /build/unbound && \
    git checkout release-1.19.3

# 设置工作目录
WORKDIR /build/unbound

# 如果有 autogen.sh 则运行，否则跳过
RUN [ -f ./autogen.sh ] && ./autogen.sh || true

# 编译并安装
RUN ./configure \
        --enable-dns-over-quic \
        --with-libevent \
        --with-ssl \
        --with-libnghttp3 \
        --with-libngtcp2 \
        --disable-shared && \
    make -j$(nproc) && \
    make install

# 添加 unbound 用户和组
RUN addgroup -S unbound && adduser -S unbound -G unbound

# 拷贝配置和证书（你需要准备这三个文件）
COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

# 创建缓存目录并赋予权限
RUN mkdir -p /var/lib/unbound && chown -R unbound:unbound /var/lib/unbound

# 设置默认命令运行 Unbound（使用非守护模式）
CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
