FROM alpine:edge

# 安装编译环境和依赖
RUN apk add --no-cache \
    build-base \
    git \
    libevent-dev \
    openssl-dev \
    libtool \
    autoconf \
    automake \
    expat-dev \
    pkgconfig \
    cmake \
    nghttp3-dev \
    ngtcp2-dev \
    curl

# 下载并编译 Unbound（支持 DoQ）
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
    make install

# 拷贝配置和证书
COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

EXPOSE 5555/udp

CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
