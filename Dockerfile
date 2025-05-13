# 第一阶段：构建阶段
FROM ubuntu:22.04 AS builder

# 安装构建依赖
RUN apt update && apt install -y \
  git autoconf automake libtool build-essential pkg-config \
  libssl-dev libevent-dev libexpat1-dev ca-certificates curl

# 构建 nghttp3
RUN git clone https://github.com/nghttp2/nghttp3.git && \
    cd nghttp3 && autoreconf -i && \
    ./configure --prefix=/usr && make -j$(nproc) && make install

# 构建 ngtcp2
RUN git clone https://github.com/nghttp2/ngtcp2.git && \
    cd ngtcp2 && autoreconf -i && \
    ./configure --prefix=/usr --with-libnghttp3=/usr && make -j$(nproc) && make install

# 构建 Unbound（开启 DNS-over-QUIC）
RUN git clone https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    git checkout release-1.19.3 && \
    ./autogen.sh && \
    ./configure \
        --enable-dns-over-quic \
        --with-libevent \
        --with-ssl \
        --with-libnghttp3=/usr \
        --with-libngtcp2=/usr \
        --prefix=/usr && \
    make -j$(nproc) && make install

# 第二阶段：运行时镜像
FROM alpine:latest

# 安装运行时依赖
RUN apk add --no-cache libevent openssl expat

# 拷贝编译好的组件
COPY --from=builder /usr/sbin/unbound /usr/sbin/
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
COPY --from=builder /usr/lib/libnghttp3.so* /usr/lib/
COPY --from=builder /usr/lib/libngtcp2*.so* /usr/lib/

# 创建配置文件目录
RUN mkdir -p /etc/unbound

# 可选：添加 unbound 配置
COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

# 创建运行目录
RUN mkdir -p /var/lib/unbound && \
    adduser -S -G unbound unbound && \
    chown -R unbound:unbound /etc/unbound /var/lib/unbound && \
    chmod 640 /etc/unbound/*

USER unbound

# 启动命令（带调试信息）
CMD ["unbound", "-dd", "-c", "/etc/unbound/unbound.conf"]
