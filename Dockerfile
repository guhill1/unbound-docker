# 第一阶段：使用 Ubuntu 编译 Unbound
FROM ubuntu:22.04 AS builder

# 安装依赖
RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    g++ \
    make \
    libssl-dev \
    libevent-dev \
    libexpat1-dev \
    pkg-config \
    tar \
    xz-utils \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 下载并解压 Unbound 源码
WORKDIR /build
RUN curl -LO https://nlnetlabs.nl/downloads/unbound/unbound-1.19.3.tar.gz && \
    tar xzf unbound-1.19.3.tar.gz && \
    cd unbound-1.19.3 && \
    ./configure --with-libevent --with-ssl --prefix=/usr && \
    make -j$(nproc) && \
    make install

# 第二阶段：Alpine 精简运行环境
FROM alpine:latest

# 安装运行时依赖
RUN apk add --no-cache \
    libevent \
    openssl \
    expat \
    shadow

# 从 builder 中复制编译好的文件
COPY --from=builder /usr/sbin/unbound /usr/sbin/
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
COPY --from=builder /usr/include/unbound.h /usr/include/
COPY --from=builder /usr/lib/pkgconfig/libunbound.pc /usr/lib/pkgconfig/

# 添加 unbound 用户
RUN addgroup -S unbound && adduser -S unbound -G unbound

# 创建配置目录
RUN mkdir -p /etc/unbound /var/lib/unbound && \
    chown -R unbound:unbound /etc/unbound /var/lib/unbound

# 复制配置文件（你需要提供 unbound.conf 文件）
COPY unbound.conf /etc/unbound/unbound.conf

# 设置权限
RUN chmod 640 /etc/unbound/unbound.conf && \
    chown unbound:unbound /etc/unbound/unbound.conf

# 设置默认运行命令
USER unbound
CMD ["unbound", "-dd", "-c", "/etc/unbound/unbound.conf"]
