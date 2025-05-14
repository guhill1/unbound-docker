# syntax=docker/dockerfile:1

# ---------- Builder Stage ----------
FROM alpine:3.21 AS builder

# 安装构建依赖
RUN apk add --no-cache \
  build-base \
  autoconf \
  automake \
  libtool \
  git \
  cmake \
  libevent-dev \
  expat-dev \
  libsodium-dev \
  libcap \
  linux-headers \
  curl \
  perl \
  python3 \
  bash \
  pkgconfig

# 设置环境变量
ENV CFLAGS="-I/usr/local/include"
ENV LDFLAGS="-L/usr/local/lib"

# ---------- Build quictls OpenSSL ----------
WORKDIR /build/openssl
RUN git clone --depth=1 --branch OpenSSL_1_1_1w+quic https://github.com/quictls/openssl.git . && \
    ./config enable-tls1_3 --prefix=/usr/local --openssldir=/usr/local && \
    make -j$(nproc) && make install_sw

# ---------- Build sfparse ----------
WORKDIR /build/sfparse
RUN git clone https://github.com/ngtcp2/sfparse.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install && \
    mkdir -p /usr/local/include/sfparse && \
    cp /usr/local/include/sfparse.h /usr/local/include/sfparse/sfparse.h && \
    mkdir -p /usr/local/src/sfparse && \
    cp sfparse.c /usr/local/src/sfparse/sfparse.c

# ---------- Build nghttp3 ----------
WORKDIR /build/nghttp3
RUN git clone --branch v1.9.0 https://github.com/ngtcp2/nghttp3.git . && \
    mkdir -p sfparse && \
    cp /usr/local/src/sfparse/sfparse.c sfparse/sfparse.c && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j$(nproc) && make install

# ---------- Build ngtcp2 ----------
WORKDIR /build/ngtcp2
RUN git clone --branch v1.9.0 https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
        --enable-lib-only \
        PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" && \
    make -j$(nproc) && make install

# ---------- Build Unbound ----------
WORKDIR /build/unbound
RUN git clone --branch release-1.19.3 https://github.com/NLnetLabs/unbound.git . && \
    ./autogen.sh && \
    ./configure --prefix=/usr/local \
        --with-ssl=/usr/local \
        --with-libevent \
        --enable-dnscrypt \
        --enable-tfo-client \
        --enable-tfo-server \
        --enable-subnet \
        --enable-dnstap \
        --enable-dns-over-tls \
        --enable-dns-over-quic \
        PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" && \
    make -j$(nproc) && make install

# ---------- Final Image ----------
FROM alpine:3.21 AS runtime

RUN apk add --no-cache \
  libevent \
  expat \
  libsodium \
  libcap \
  bash \
  ca-certificates

COPY --from=builder /usr/local /usr/local

# 设置路径
ENV PATH="/usr/local/sbin:/usr/local/bin:$PATH"

# 默认启动 Unbound
CMD ["unbound", "-d"]
