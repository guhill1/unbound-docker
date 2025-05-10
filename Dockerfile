# 使用最新的 Alpine 镜像
FROM alpine:latest

# 启用边缘仓库
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk update || { echo "apk update failed"; exit 1; }

# 安装构建工具
RUN apk add --no-cache git autoconf automake libtool gcc g++ make pkgconf openssl-dev

# 编译 nghttp3
RUN apk add --no-cache nghttp3-dev || \
    (git clone https://github.com/nghttp2/nghttp3.git && \
     cd nghttp3 && \
     autoreconf -i && \
     ./configure --prefix=/usr && \
     make -j$(nproc) && \
     make install && \
     cd .. && rm -rf nghttp3 && \
     ls -l /usr/lib/pkgconfig/nghttp3.pc || { echo "nghttp3.pc not found"; find / -name nghttp3.pc; exit 1; })

# 编译 ngtcp2
RUN apk add --no-cache ngtcp2-dev || \
    (git clone https://github.com/ngtcp2/ngtcp2.git && \
     cd ngtcp2 && \
     autoreconf -i && \
     ./configure --prefix=/usr && \
     make -j$(nproc) && \
     make install && \
     cd .. && rm -rf ngtcp2 && \
     ls -l /usr/lib/pkgconfig/ngtcp2.pc || { echo "ngtcp2.pc not found"; find / -name ngtcp2.pc; exit 1; })

# 设置 pkg-config 路径
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig

# 安装其他依赖
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
    flex \
    bison \
    expat-dev \
    shadow \
    pkgconf

# 验证 nghttp3 和 ngtcp2
RUN pkg-config --modversion nghttp3 || { echo "nghttp3 not found"; find / -name nghttp3.pc; exit 1; }
RUN pkg-config --modversion ngtcp2 || { echo "ngtcp2 not found"; find / -name ngtcp2.pc; exit 1; }

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
