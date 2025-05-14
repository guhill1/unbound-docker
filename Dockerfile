# =====================================
# Stage 1: Build all dependencies
# =====================================
FROM alpine:3.21 AS builder

# 安装构建依赖
RUN apk add --no-cache \
  build-base \
  autoconf \
  automake \
  libtool \
  git \
  cmake \
  curl \
  libevent-dev \
  expat-dev \
  libsodium-dev \
  libcap \
  linux-headers \
  bash \
  perl \
  pkgconfig

WORKDIR /build

# -------------------------------------
# 构建 quictls OpenSSL (QUIC-enabled)
# -------------------------------------
WORKDIR /build/openssl
RUN git clone --depth 1 -b OpenSSL_1_1_1u+quic https://github.com/quictls/openssl.git . && \
    ./config enable-tls1_3 --prefix=/usr/local --openssldir=/usr/local && \
    make -j$(nproc) && make install_sw

ENV CFLAGS="-I/usr/local/include"
ENV LDFLAGS="-L/usr/local/lib"

# -------------------------------------
# 构建 sfparse 并修复头文件路径
# -------------------------------------
WORKDIR /build/sfparse
RUN git clone https://github.com/ngtcp2/sfparse.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install && \
    mkdir -p /usr/local/include/sfparse && \
    cp /usr/local/include/sfparse.h /usr/local/include/sfparse/sfparse.h

# -------------------------------------
# 构建 nghttp3
# -------------------------------------
WORKDIR /build/nghttp3
RUN git clone --branch v1.9.0 https://github.com/ngtcp2/nghttp3.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j$(nproc) && make install

# -------------------------------------
# 构建 ngtcp2
# -------------------------------------
WORKDIR /build/ngtcp2
RUN git clone --branch v1.9.0 https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
        PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" && \
    make -j$(nproc) && make install

# -------------------------------------
# 构建 Unbound 1.19.3
# -------------------------------------
WORKDIR /build/unbound
RUN curl -LO https://www.nlnetlabs.nl/downloads/unbound/unbound-1.19.3.tar.gz && \
    tar xzf unbound-1.19.3.tar.gz && \
    cd unbound-1.19.3 && \
    ./configure --prefix=/usr/local \
        --with-ssl=/usr/local \
        --with-libevent=/usr \
        --enable-subnet \
        --enable-dnscrypt \
        --enable-cachedb \
        --enable-tfo-client \
        --enable-tfo-server \
        --enable-quic \
        CFLAGS="-I/usr/local/include" \
        LDFLAGS="-L/usr/local/lib" && \
    make -j$(nproc) && make install

# =====================================
# Final runtime image
# =====================================
FROM alpine:3.21

# 安装运行依赖
RUN apk add --no-cache libevent libcap expat libsodium

# 拷贝 Unbound 和所有库
COPY --from=builder /usr/local /usr/local

ENV PATH="/usr/local/sbin:$PATH"

# 默认命令
CMD ["unbound", "-d"]
