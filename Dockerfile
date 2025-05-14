FROM alpine:3.19 AS builder

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
  openssl-dev \
  pkgconf

# 设置 include / lib 搜索路径（供 sfparse/nghttp3/ngtcp2/unbound 使用）
ENV CFLAGS="-I/usr/local/include"
ENV LDFLAGS="-L/usr/local/lib"

WORKDIR /build

# 构建 quictls（支持 QUIC 的 OpenSSL 分支）
RUN git clone --depth=1 --branch OpenSSL_1_1_1u+quic https://github.com/quictls/openssl.git && \
    cd openssl && \
    ./config --prefix=/usr/local --openssldir=/usr/local no-shared && \
    make -j$(nproc) && \
    make install_sw

# 构建 sfparse
WORKDIR /build/sfparse
RUN git clone --depth=1 https://github.com/ngtcp2/sfparse.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# 构建 nghttp3
WORKDIR /build/nghttp3
RUN git clone --branch v1.9.0 https://github.com/ngtcp2/nghttp3.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j$(nproc) && \
    make install

# 构建 ngtcp2
WORKDIR /build/ngtcp2
RUN git clone --branch v1.9.0 https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --enable-lib-only \
      --with-openssl --with-libnghttp3=/usr/local && \
    make -j$(nproc) && \
    make install

# 构建 unbound（支持 DNS-over-QUIC）
WORKDIR /build/unbound
RUN git clone --branch release-1.19.3 https://github.com/NLnetLabs/unbound.git . && \
    ./autogen.sh && \
    ./configure --prefix=/opt/unbound \
      --with-ssl=/usr/local \
      --with-libngtcp2=/usr/local \
      --with-libnghttp3=/usr/local \
      --enable-dns-over-quic \
      --enable-dnscrypt \
      --disable-static \
      --enable-shared && \
    make -j$(nproc) && \
    make install

# 生产镜像（仅复制最终产物）
FROM alpine:3.19 AS final

RUN apk add --no-cache libevent expat libsodium libcap openssl

COPY --from=builder /opt/unbound /opt/unbound

ENV PATH="/opt/unbound/sbin:$PATH"

# 默认启动命令（你可以改成 CMD ["unbound", "-d"]）
CMD ["unbound", "-V"]
