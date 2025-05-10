# 使用最新的 Alpine 镜像
FROM alpine:latest

# 启用边缘仓库
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk update || { echo "apk update failed"; exit 1; }

# 安装构建所需依赖
RUN set -x && \
    apk add --no-cache \
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
        expat-dev \
        shadow \
        pkgconf && \
    pkg-config --modversion nghttp3 && \
    pkg-config --modversion ngtcp2 || { echo "Command failed"; exit 1; }

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
    grep -i quic config.log && \
    make -j$(nproc) && \
    make install && \
    unbound -V

# 添加 unbound 用户和组
RUN addgroup -S unbound && adduser -S unbound -G unbound && \
    id unbound && getent group unbound

# 拷贝配置和证书
COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

# 验证文件并设置权限
RUN ls -l /etc/unbound/ && \
    test -f /etc/unbound/unbound.conf && \
    test -f /etc/unbound/unbound_server.key && \
    test -f /etc/unbound/unbound_server.pem && \
    mkdir -p /etc/unbound /var/lib/unbound && \
    chown -R unbound:unbound /etc/unbound /var/lib/unbound && \
    chmod 640 /etc/unbound/unbound.conf /etc/unbound/unbound_server.key /etc/unbound/unbound_server.pem

# 以 unbound 用户运行
USER unbound

# 设置默认命令运行 Unbound（调试模式）
CMD ["unbound", "-dd", "-c", "/etc/unbound/unbound.conf"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s \
    CMD unbound-control status || exit 1
