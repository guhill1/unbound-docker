# ========== Stage 1: Build all dependencies ==========
FROM alpine:3.21 AS builder

# 安装构建工具和依赖
RUN apk add --no-cache \
  build-base \
  autoconf \
  automake \
  libtool \
  git \
  cmake \
  linux-headers \
  curl \
  libevent-dev \
  expat-dev \
  libsodium-dev \
  bash \
  pkgconf

WORKDIR /build

# --------- Build OpenSSL (quictls branch) ------------
WORKDIR /build/openssl
RUN git clone --depth=1 --branch openssl-3.1.5 https://github.com/quictls/openssl.git . && \
    ./config --prefix=/usr/local --openssldir=/usr/local/ssl no-shared && \
    make -j$(nproc) && make install_sw

ENV PATH="/usr/local/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib"

# --------- Build sfparse ----------
WORKDIR /build/sfparse
RUN git clone https://github.com/ngtcp2/sfparse.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install

# ✅ 检查 sfparse 是否成功被识别
RUN pkg-config --modversion sfparse || (echo "sfparse not found via pkg-config" && exit 1)

# --------- Build nghttp3 ----------
WORKDIR /build/nghttp3
RUN git clone https://github.com/ngtcp2/nghttp3.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j$(nproc) && make install

# --------- Build ngtcp2 ----------
WORKDIR /build/ngtcp2
RUN git clone https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
      PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" \
      --with-openssl && \
    make -j$(nproc) && make install

# --------- Build Unbound ----------
WORKDIR /build/unbound
RUN curl -LO https://nlnetlabs.nl/downloads/unbound/unbound-1.19.3.tar.gz && \
    tar xzf unbound-1.19.3.tar.gz && \
    cd unbound-1.19.3 && \
    ./configure --prefix=/usr/local \
      --with-ssl=/usr/local \
      --with-libevent \
      --enable-dnscrypt \
      --enable-dnstap \
      --enable-subnet \
      --enable-tfo-client \
      --enable-ecdsa \
      --enable-ed25519 \
      --enable-dns-over-tls \
      --enable-dns-over-https \
      --enable-dns-over-quic \
      PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" && \
    make -j$(nproc) && make install

# ========== Stage 2: Final image ==========
FROM alpine:3.21

RUN apk add --no-cache libevent openssl libsodium expat

COPY --from=builder /usr/local /usr/local

ENV PATH="/usr/local/sbin:/usr/local/bin:$PATH"

ENTRYPOINT ["unbound"]
CMD ["-d", "-c", "/etc/unbound/unbound.conf"]
