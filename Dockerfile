FROM alpine:3.19 AS builder

# 安装构建工具和依赖
RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    pkgconfig \
    git \
    wget \
    curl \
    libevent-dev \
    expat-dev \
    libsodium-dev \
    linux-headers \
    bash \
    cmake \
    doxygen

WORKDIR /

### 1. Build OpenSSL (QUIC-enabled) from quictls
RUN git clone --depth=1 -b OpenSSL_1_1_1w+quic https://github.com/quictls/openssl.git && \
    cd openssl && \
    ./config no-shared --prefix=/usr/local && \
    make -j$(nproc) && make install_sw

ENV PATH="/usr/local/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

### 2. Build sfparse (for nghttp3)
RUN git clone --depth=1 https://github.com/ngtcp2/sfparse.git && \
    cd sfparse && \
    cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local && \
    cmake --build build -j$(nproc) && \
    cmake --install build

### 3. Build nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install

### 4. Build ngtcp2
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j$(nproc) && make install

### 5. Build Unbound with QUIC support
RUN git clone --depth=1 -b release-1.19.3 https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
        --enable-dns-over-tls \
        --enable-dnscrypt \
        --with-ssl=/usr/local \
        --with-libevent=/usr && \
    make -j$(nproc) && make install

---

FROM alpine:3.19

RUN apk add --no-cache libevent libsodium expat

# 拷贝已构建的 Unbound 和依赖库
COPY --from=builder /usr/local /usr/local

ENV PATH="/usr/local/sbin:/usr/local/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib"

CMD ["unbound", "-d"]
