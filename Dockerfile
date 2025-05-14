# ---------- Stage 1: Build environment ----------
FROM alpine:3.21 AS builder

ENV OPENSSL_DIR=/opt/quictls \
    NGHTTP3_VER=v1.9.0 \
    NGTCP2_VER=v1.9.0

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
    pkgconf

# ---------- Build sfparse ----------
WORKDIR /build/sfparse
RUN git clone https://github.com/ngtcp2/sfparse.git . && \
    mkdir -p /tmp/sfparse-copy && \
    cp sfparse.c /tmp/sfparse-copy/sfparse.c && \
    cp sfparse.h /tmp/sfparse-copy/sfparse.h && \
    autoreconf -fi && ./configure --prefix=/usr/local && make -j$(nproc) && make install

# ---------- Build nghttp3 ----------
WORKDIR /build/nghttp3
RUN git clone --branch ${NGHTTP3_VER} https://github.com/ngtcp2/nghttp3.git . && \
    mkdir -p lib/sfparse && \
    cp /tmp/sfparse-copy/sfparse.c lib/sfparse/sfparse.c && \
    cp /tmp/sfparse-copy/sfparse.h lib/sfparse/sfparse.h && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j$(nproc) && make install

# ---------- Build OpenSSL (quictls) ----------
WORKDIR /build/quictls
RUN git clone --depth 1 -b openssl-3.1.5+quic https://github.com/quictls/openssl.git . && \
    ./Configure enable-tls1_3 --prefix=${OPENSSL_DIR} linux-x86_64 && \
    make -j$(nproc) && make install_sw && \
    echo ">>> OpenSSL installed in ${OPENSSL_DIR}" && \
    ls -l ${OPENSSL_DIR}/lib && \
    \
    # 补充 openssl.pc 文件，供 ngtcp2 检测用
    mkdir -p ${OPENSSL_DIR}/lib/pkgconfig && \
    echo "prefix=${OPENSSL_DIR}" > ${OPENSSL_DIR}/lib/pkgconfig/openssl.pc && \
    echo "exec_prefix=\${prefix}" >> ${OPENSSL_DIR}/lib/pkgconfig/openssl.pc && \
    echo "libdir=\${exec_prefix}/lib" >> ${OPENSSL_DIR}/lib/pkgconfig/openssl.pc && \
    echo "includedir=\${prefix}/include" >> ${OPENSSL_DIR}/lib/pkgconfig/openssl.pc && \
    echo "" >> ${OPENSSL_DIR}/lib/pkgconfig/openssl.pc && \
    echo "Name: OpenSSL" >> ${OPENSSL_DIR}/lib/pkgconfig/openssl.pc && \
    echo "Description: Secure Sockets Layer and cryptography libraries" >> ${OPENSSL_DIR}/lib/pkgconfig/openssl.pc && \
    echo "Version: 3.1.5" >> ${OPENSSL_DIR}/lib/pkgconfig/openssl.pc && \
    echo "Libs: -L\${libdir} -lssl -lcrypto" >> ${OPENSSL_DIR}/lib/pkgconfig/openssl.pc && \
    echo "Cflags: -I\${includedir}" >> ${OPENSSL_DIR}/lib/pkgconfig/openssl.pc && \
    echo ">>> openssl.pc 内容如下:" && cat ${OPENSSL_DIR}/lib/pkgconfig/openssl.pc && \
    PKG_CONFIG_PATH="${OPENSSL_DIR}/lib/pkgconfig" pkg-config --modversion openssl || echo "pkg-config failed"

# ---------- Build ngtcp2 ----------
WORKDIR /build/ngtcp2
RUN git clone --branch ${NGTCP2_VER} https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    export PKG_CONFIG_PATH="${OPENSSL_DIR}/lib/pkgconfig" && \
    ./configure --prefix=/usr/local \
        LDFLAGS="-Wl,-rpath,${OPENSSL_DIR}/lib" \
        --with-openssl \
        --with-libnghttp3 \
        --enable-lib-only && \
    make -j$(nproc) && make install

# ---------- Build Unbound ----------
WORKDIR /build/unbound
RUN git clone https://github.com/NLnetLabs/unbound.git . && \
    git checkout release-1.19.3 && \
    ./configure \
      --prefix=/usr/local \
      --with-libevent \
      --with-libngtcp2 \
      --with-libnghttp3 \
      --enable-dns-over-quic \
      PKG_CONFIG_PATH="${OPENSSL_DIR}/lib/pkgconfig" \
      LDFLAGS="-Wl,-rpath,${OPENSSL_DIR}/lib" && \
    make -j$(nproc) && make install

# ---------- Stage 2: Final image ----------
FROM alpine:3.21

RUN apk add --no-cache libevent libcap expat libsodium

COPY --from=builder /usr/local /usr/local
COPY --from=builder /opt/quictls /opt/quictls

ENV PATH=/usr/local/sbin:$PATH

EXPOSE 853/udp 853/tcp 8853/udp
ENTRYPOINT ["/usr/local/sbin/unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
