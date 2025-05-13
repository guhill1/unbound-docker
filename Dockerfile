# 第一阶段：使用Ubuntu编译 nghttp3、ngtcp2 和 Unbound（无QUIC）
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

# 克隆并编译 Unbound（不启用 QUIC）
RUN mkdir -p ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git config --global credential.helper '!f() { :; }; f' && \
    git clone https://github.com/NLnetLabs/unbound.git /build/unbound || { echo "git clone unbound failed"; exit 1; }

RUN cd /build/unbound && \
    git checkout release-1.19.3 && \
    [ -f ./autogen.sh ] && ./autogen.sh || true && \
    ./configure \
        --with-libevent \
        --with-ssl \
        --prefix=/usr \
        --disable-shared && \
    make -j$(nproc) && \
    make install

# 验证编译结果
RUN unbound -V

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
COPY --from=builder /usr/sbin/unbound /usr/sbin/
COPY --from=builder /usr/bin/unbound-control /usr/bin/
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
COPY --from=builder /usr/include/unbound.h /usr/include/
COPY --from=builder /usr/lib/pkgconfig/libunbound.pc /usr/lib/pkgconfig/

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
