# ---------- Stage 1: Build environment ----------
FROM debian:bookworm AS builder

ENV OPENSSL_DIR=/opt/quictls \
    NGHTTP3_VER=v1.9.0 \
    NGTCP2_VER=v1.9.0

# ✅ 将 apk 替换为 apt
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    autoconf \
    automake \
    libtool \
    git \
    cmake \
    libevent-dev \
    libexpat1-dev \
    libsodium-dev \
    libcap-dev \
    linux-headers-amd64 \
    curl \
    pkgconf \
    flex \
    bison \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build/sfparse
RUN git clone https://github.com/ngtcp2/sfparse.git . && \
    mkdir -p /tmp/sfparse-copy && \
    cp sfparse.c /tmp/sfparse-copy/sfparse.c && \
    cp sfparse.h /tmp/sfparse-copy/sfparse.h && \
    autoreconf -fi && ./configure --prefix=/usr/local && make -j$(nproc) && make install

WORKDIR /build/nghttp3
RUN git clone --branch ${NGHTTP3_VER} https://github.com/ngtcp2/nghttp3.git . && \
    mkdir -p lib/sfparse && \
    cp /tmp/sfparse-copy/sfparse.c lib/sfparse/sfparse.c && \
    cp /tmp/sfparse-copy/sfparse.h lib/sfparse/sfparse.h && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j$(nproc) && make install

WORKDIR /build/quictls
RUN git clone --depth 1 -b openssl-3.1.5+quic https://github.com/quictls/openssl.git . && \
    ./Configure enable-tls1_3 --prefix=${OPENSSL_DIR} linux-x86_64 && \
    make -j$(nproc) && make install_sw && \
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
    echo "Cflags: -I\${includedir}" >> ${OPENSSL_DIR}/lib/pkgconfig/openssl.pc

WORKDIR /build/ngtcp2
RUN git clone --branch ${NGTCP2_VER} https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    export PKG_CONFIG_PATH="${OPENSSL_DIR}/lib/pkgconfig" && \
    ./configure --prefix=/usr/local \
        LDFLAGS="-Wl,-rpath,${OPENSSL_DIR}/lib" \
        --with-openssl=${OPENSSL_DIR} \
        --with-libnghttp3 \
        --enable-lib-only && \
    make -j$(nproc) && make install

WORKDIR /build/unbound

ENV OPENSSL_DIR=/opt/quictls \
    OPENSSL_CFLAGS="-I/opt/quictls/include" \
    OPENSSL_LIBS="-L/opt/quictls/lib -lssl -lcrypto -Wl,-rpath,/opt/quictls/lib" \
    PKG_CONFIG_PATH="/opt/quictls/lib/pkgconfig" \
    CPPFLAGS="-I/opt/quictls/include" \
    CFLAGS="-I/opt/quictls/include" \
    LDFLAGS="-L/opt/quictls/lib -Wl,-rpath,/opt/quictls/lib" \
    PATH="/opt/quictls/bin:$PATH"

RUN LD_LIBRARY_PATH=/opt/quictls/lib /opt/quictls/bin/openssl version

RUN git clone https://github.com/NLnetLabs/unbound.git . && \
    git checkout release-1.19.3 && \
    autoreconf -fi && \
    ./configure \
      --prefix=/usr/local \
      --with-libevent \
      --with-libngtcp2 \
      --with-libnghttp3 \
      --with-ssl=/opt/quictls \
      --enable-dns-over-quic && \
    make -j$(nproc) && make install


# ---------- Stage 2: Final image ----------
FROM alpine:3.21

RUN apk add --no-cache libevent libcap expat libsodium

COPY --from=builder /usr/local /usr/local
COPY --from=builder /opt/quictls /opt/quictls
COPY --from=builder /opt/quictls/lib/*.so* /usr/lib/

ENV PATH=/usr/local/sbin:$PATH

EXPOSE 853/udp 853/tcp 8853/udp
ENTRYPOINT ["/usr/local/sbin/unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
