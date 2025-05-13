# ===== Stage 1: Build dependencies and unbound =====
FROM alpine:latest AS builder

# 安装构建依赖
RUN apk add --no-cache \
    autoconf automake libtool pkgconfig build-base \
    openssl-dev libevent-dev libcap-dev \
    git bash linux-headers c-ares-dev \
    autoconf automake libtool

# 编译 nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && make install

# 编译 nghttp2
RUN git clone --depth=1 https://github.com/nghttp2/nghttp2.git && \
    cd nghttp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && make install

# 编译 ngtcp2（需要 nghttp3 和 nghttp2）
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr \
        --with-openssl \
        --with-nghttp3=/usr \
        --with-nghttp2=/usr && \
    make -j$(nproc) && make install

# 编译 Unbound（支持 QUIC）
RUN git clone --branch release-1.19.3 https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    autoreconf -fi && \
    ./configure --prefix=/usr \
        --enable-event-api \
        --with-libevent \
        --with-ssl \
        --with-libngtcp2=/usr \
        --with-libnghttp3=/usr && \
    make -j$(nproc) && make install

# ===== Stage 2: Runtime image =====
FROM alpine:latest

# 安装运行时依赖
RUN apk add --no-cache libevent libcrypto libssl

# 复制二进制和必要文件
COPY --from=builder /usr/sbin/unbound /usr/sbin/unbound
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
COPY --from=builder /usr/include/unbound.h /usr/include/
COPY --from=builder /usr/share/unbound /usr/share/unbound

# 配置文件目录
VOLUME /etc/unbound

# 默认执行命令
CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
