# 第一阶段：构建 Unbound
FROM ubuntu:22.04 AS builder

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
    libexpat1-dev \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 拉取源码并编译 Unbound（无 QUIC）
RUN git clone https://github.com/NLnetLabs/unbound.git /build/unbound
WORKDIR /build/unbound

RUN git checkout release-1.19.3 && \
    ./autogen.sh && \
    ./configure \
        --with-libevent \
        --with-ssl \
        --prefix=/usr && \
    make -j$(nproc) && \
    make install

# 第二阶段：构建最小运行镜像
FROM alpine:latest

# 安装运行时依赖
RUN apk update && apk add --no-cache \
    libevent \
    openssl \
    expat \
    shadow

# 添加运行用户
RUN addgroup -S unbound && adduser -S unbound -G unbound

# 拷贝构建好的 Unbound
COPY --from=builder /usr/sbin/unbound /usr/sbin/
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
COPY --from=builder /usr/include/unbound.h /usr/include/
COPY --from=builder /usr/lib/pkgconfig/libunbound.pc /usr/lib/pkgconfig/

# 拷贝配置与证书
COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

# 设置权限
RUN mkdir -p /etc/unbound /var/lib/unbound && \
    chown -R unbound:unbound /etc/unbound /var/lib/unbound && \
    chmod 640 /etc/unbound/unbound.conf /etc/unbound/unbound_server.* || true

# 设置运行用户
USER unbound

# 启动命令（调试模式）
CMD ["unbound", "-dd", "-c", "/etc/unbound/unbound.conf"]
