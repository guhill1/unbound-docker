FROM alpine:edge

# 安装编译环境和构建工具
RUN apk add --no-cache \
    build-base \
    git \
    libevent-dev \
    openssl-dev \
    expat-dev \
    libtool \
    autoconf \
    automake \
    cmake \
    pkgconfig \
    nghttp3-dev \
    ngtcp2-dev \
    curl

# 克隆并编译 Unbound
RUN git clone https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    git checkout release-1.19.3 && \
    ./autogen.sh && \
    ./configure \
        --enable-dns-over-quic \
        --with-libevent \
        --with-ssl \
        --with-libnghttp3 \
        --with-libngtcp2 \
        --disable-shared && \
    make -j$(nproc) && \
    make install && \
    cd .. && rm -rf unbound

# 添加配置和证书
COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

EXPOSE 53/udp

CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
