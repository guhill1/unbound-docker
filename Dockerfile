FROM alpine:latest

RUN apk add --no-cache \
    git \
    autoconf \
    automake \
    libtool \
    gcc \
    g++ \
    make \
    bash \
    libevent-dev \
    openssl-dev \
    nghttp3-dev \
    ngtcp2-dev \
    flex \
    bison \
    expat-dev

# 克隆 Unbound 源码
RUN git clone https://github.com/NLnetLabs/unbound.git /build/unbound && \
    cd /build/unbound && \
    git checkout release-1.19.3

WORKDIR /build/unbound

# 生成 configure 文件并配置
RUN ./autogen.sh && \
    ./configure \
        --enable-dns-over-quic \
        --with-libevent \
        --with-ssl \
        --with-libnghttp3 \
        --with-libngtcp2 \
        --disable-shared

# 编译安装
RUN make -j$(nproc) && make install

# 清理
RUN cd / && rm -rf /build/unbound

# 复制配置与证书（你必须确保下面三个文件都在构建目录）
COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

# 监听 443 UDP（DoQ）
EXPOSE 443/udp

CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
