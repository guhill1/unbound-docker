FROM alpine:3.19 as builder

RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    git \
    wget \
    curl \
    openssl-dev \
    libevent-dev \
    expat-dev \
    libsodium-dev \
    pkgconfig \
    libcap \
    linux-headers \
    cmake

# 安装 OpenSSL (使用 quictls 分支支持 QUIC)
WORKDIR /build/openssl
RUN git clone --depth=1 -b OpenSSL_1_1_1q+quic https://github.com/quictls/openssl.git . && \
    ./config enable-tls1_3 no-shared --prefix=/usr/local && \
    make -j$(nproc) && make install_sw

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV LD_LIBRARY_PATH=/usr/local/lib

# 构建 sfparse
WORKDIR /build/sfparse
RUN git clone --depth=1 https://github.com/ngtcp2/sfparse.git . && \
    cmake -B build -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j$(nproc) && \
    cmake --install build --prefix /usr/local

# 构建 nghttp3
WORKDIR /build/nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git . && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install

# 构建 ngtcp2
WORKDIR /build/ngtcp2
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -i && \
    ./configure --prefix=/usr/local --with-openssl --with-libnghttp3 && \
    make -j$(nproc) && make install

# 构建 Unbound（支持 DNS-over-QUIC）
WORKDIR /build/unbound
RUN git clone --depth=1 --branch release-1.19.3 https://github.com/NLnetLabs/unbound.git . && \
    ./autogen.sh && \
    ./configure --prefix=/opt/unbound \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-subnet \
        --enable-tfo-client \
        --enable-tfo-server \
        --enable-tls \
        --with-libngtcp2 \
        --with-libnghttp3 \
        --with-ssl=/usr/local && \
    make -j$(nproc) && make install

# 最终运行镜像
FROM alpine:3.19

COPY --from=builder /opt/unbound /opt/unbound
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/include /usr/local/include

RUN apk add --no-cache \
    libevent \
    openssl \
    libsodium \
    expat && \
    mkdir -p /etc/unbound

ENV PATH="/opt/unbound/sbin:$PATH"

CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
