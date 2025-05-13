# --------- builder阶段：构建依赖和Unbound本体 ---------
FROM alpine:3.20 AS builder

RUN apk add --no-cache \
    build-base \
    git \
    autoconf \
    automake \
    libtool \
    openssl-dev \
    libevent-dev \
    c-ares-dev \
    libcap-dev \
    linux-headers \
    pkgconfig \
    cmake \
    bash \
    curl

WORKDIR /build

# 获取 nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && make install

# 获取 ngtcp2
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr --with-nghttp3=/usr && \
    make -j$(nproc) && make install

# 获取 unbound 源码（最新版本）
RUN git clone --branch release-1.19.3 --depth=1 https://github.com/NLnetLabs/unbound.git

# 编译 Unbound，启用 DoQ
WORKDIR /build/unbound
RUN ./autogen.sh && \
    ./configure --prefix=/usr \
        --with-libevent \
        --with-ssl \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-subnet \
        --enable-tfo-client \
        --enable-tfo-server \
        --enable-checking \
        --with-libngtcp2=/usr \
        --with-libnghttp3=/usr \
        --enable-dns-over-quic && \
    make -j$(nproc) && make install

# --------- stage-1：最终镜像 ---------
FROM alpine:3.20

RUN apk add --no-cache libevent openssl libcap libgcc

# 拷贝已编译的 Unbound 二进制及所需库
COPY --from=builder /usr/sbin/unbound /usr/sbin/
COPY --from=builder /usr/bin/unbound-control /usr/bin/
COPY --from=builder /usr/lib/libunbound.so* /usr/lib/
COPY --from=builder /usr/include/unbound.h /usr/include/

# 可选: 拷贝 ngtcp2/nghttp3 库（DoQ 依赖）
COPY --from=builder /usr/lib/libngtcp2*.so* /usr/lib/
COPY --from=builder /usr/lib/libnghttp3*.so* /usr/lib/

# 创建基本配置目录
RUN mkdir -p /etc/unbound

# 默认命令
CMD ["unbound", "-d"]
