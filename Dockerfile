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

# 克隆 Unbound 并切换分支
RUN git clone https://github.com/NLnetLabs/unbound.git /build/unbound && \
    cd /build/unbound && \
    git checkout release-1.19.3

WORKDIR /build/unbound

# 直接 configure，不需要 autogen.sh
RUN ./configure \
        --enable-dns-over-quic \
        --with-libevent \
        --with-ssl \
        --with-libnghttp3 \
        --with-libngtcp2 \
        --disable-shared

RUN make -j$(nproc) && make install

RUN cd / && rm -rf /build/unbound

COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

EXPOSE 443/udp

CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
