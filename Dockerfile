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

# 编译 nghttp3 - 分离步骤
# 1. 克隆仓库（配置SSH主机密钥）
RUN mkdir -p ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git config --global credential.helper '!f() { :; }; f' && \
    git clone git@github.com:nghttp2/nghttp3.git || { echo "git clone nghttp3 failed"; exit 1; }

# 2. 进入目录
RUN cd nghttp3 || { echo "cd nghttp3 failed"; exit 1; }

# 3. 运行 autoreconf
RUN cd nghttp3 && autoreconf -i || { echo "autoreconf failed"; exit 1; }

# 4. 运行 configure
RUN cd nghttp3 && ./configure --prefix=/usr || { echo "configure nghttp3 failed"; cat config.log; exit 1; }

# 5. 编译
RUN cd nghttp3 && make -j$(nproc) || { echo "make nghttp3 failed"; exit 1; }

# 6. 安装
RUN cd nghttp3 && make install || { echo "make install nghttp3 failed"; exit 1; }

# 7. 清理
RUN rm -rf nghttp3 || { echo "cleanup nghttp3 failed"; exit 1; }

# 验证 nghttp3 安装
RUN pkg-config --modversion nghttp3 || { echo "nghttp3 pkg-config failed"; find / -name nghttp3.pc; exit 1; }

# 编译 ngtcp2（类似分离步骤）
RUN mkdir -p ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git config --global credential.helper '!f() { :; }; f' && \
    git clone git@github.com:ngtcp2/ngtcp2.git || { echo "git clone ngtcp2 failed"; exit 1; }
RUN cd ngtcp2 || { echo "cd ngtcp2 failed"; exit 1; }
RUN cd ngtcp2 && autoreconf -i || { echo "autoreconf ngtcp2 failed"; exit 1; }
RUN cd ngtcp2 && ./configure --prefix=/usr || { echo "configure ngtcp2 failed"; cat config.log; exit 1; }
RUN cd ngtcp2 && make -j$(nproc) || { echo "make ngtcp2 failed"; exit 1; }
RUN cd ngtcp2 && make install || { echo "make install ngtcp2 failed"; exit 1; }
RUN rm -rf ngtcp2 || { echo "cleanup ngtcp2 failed"; exit 1; }

# 验证 ngtcp2 安装
RUN pkg-config --modversion ngtcp2 || { echo "ngtcp2 pkg-config failed"; find / -name ngtcp2.pc; exit 1; }

# 克隆并编译 Unbound
RUN mkdir -p ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git config --global credential.helper '!f() { :; }; f' && \
    git clone git@github.com:NLnetLabs/unbound.git /build/unbound || { echo "git clone unbound failed"; exit 1; }
RUN cd /build/unbound && \
    git checkout release-1.19.3 && \
    [ -f ./autogen.sh ] && ./autogen.sh || true && \
    ./configure \
        --enable-dns-over-quic \
        --with-libevent \
        --with-ssl \
        --with-libnghttp3 \
        --with-libngtcp2 \
        --prefix=/usr \
        --disable-shared && \
    make -j$(nproc) && \
    make install

# 验证编译结果
RUN unbound -V && \
    pkg-config --modversion nghttp3 && \
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
COPY --from=builder /usr/lib/libnghttp3.so* /usr/lib/
COPY --from=builder /usr/lib/libngtcp2.so* /usr/lib/
COPY --from=builder /usr/lib/libngtcp2_crypto_*.so* /usr/lib/
COPY --from=builder /usr/sbin/unbound /usr/sbin/
COPY --from=builder /usr/bin/unbound-control /usr/bin/
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
COPY --from=builder /usr/include/unbound.h /usr/include/
COPY --from=builder /usr/lib/pkgconfig/libunbound.pc /usr/lib/pkgconfig/
COPY --from=builder /usr/lib/pkgconfig/nghttp3.pc /usr/lib/pkgconfig/
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
