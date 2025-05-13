# 第一阶段：使用Ubuntu编译 nghttp3、ngtcp2 和 Unbound
FROM ubuntu:22.04 AS builder

# 安装构建工具和依赖
RUN apt-get update && apt-get install -y \
    git \
    autoconf \
    automake \
    libtool \
    gcc \
    g++ \
    make \
    pkg-config \
    libssl-dev \
    libevent-dev \
    flex \
    bison \
    libexpat1-dev \
    ca-certificates \
    curl \
    openssh-client \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 验证 git 安装和网络
RUN git --version || { echo "git not installed"; exit 1; } && \
    curl -s -I https://github.com || { echo "cannot reach github.com"; exit 1; }

# 编译 nghttp2（包含 nghttp3 支持）- 分离步骤
# 1. 克隆仓库
RUN git clone https://github.com/nghttp2/nghttp2.git && \
    cd nghttp2 && \
    git checkout master && \
    autoreconf -i && \
    ./configure --prefix=/usr && make -j$(nproc) && make install

# 验证 nghttp2 安装
RUN pkg-config --modversion nghttp2 || { echo "nghttp2 pkg-config failed"; exit 1; }

# 编译 ngtcp2（类似分离步骤）
RUN git clone https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && autoreconf -i && \
    ./configure --prefix=/usr --with-libnghttp2=/usr && make -j$(nproc) && make install

# 验证 ngtcp2 安装
RUN pkg-config --modversion ngtcp2 || { echo "ngtcp2 pkg-config failed"; exit 1; }

# 克隆并编译 Unbound
RUN git clone https://github.com/NLnetLabs/unbound.git /build/unbound || { echo "git clone unbound failed"; exit 1; }
RUN cd /build/unbound && \
    git checkout release-1.19.3 && \
    [ -f ./autogen.sh ] && ./autogen.sh || true && \
    ./configure \
        --enable-dns-over-quic \
        --with-libevent \
        --with-ssl \
        --with-libnghttp2 \
        --with-libngtcp2 \
        --prefix=/usr \
        --disable-shared && \
    make -j$(nproc) && \
    make install

# 验证编译结果
RUN unbound -V && \
    pkg-config --modversion nghttp2 && \
    pkg-config --modversion ngtcp2

# 第二阶段：使用Alpine构建运行时镜像
FROM alpine:latest

# 安装运行时依赖
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk update && \
    apk add --no-cache \
        libevent \
        openssl \
        expat \
        shadow

# 从第一阶段复制编译好的文件
COPY --from=builder /usr/lib/libnghttp2.so* /usr/lib/
COPY --from=builder /usr/lib/libngtcp2.so* /usr/lib/
COPY --from=builder /usr/lib/libngtcp2_crypto_*.so* /usr/lib/
COPY --from=builder /usr/sbin/unbound /usr/sbin/
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
COPY --from=builder /usr/include/unbound.h /usr/include/
COPY --from=builder /usr/lib/pkgconfig/libunbound.pc /usr/lib/pkgconfig/
COPY --from=builder /usr/lib/pkgconfig/nghttp2.pc /usr/lib/pkgconfig/
COPY --from=builder /usr/lib/pkgconfig/ngtcp2.pc /usr/lib/pkgconfig/

# 设置 pkg-config 路径
ENV PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig

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
