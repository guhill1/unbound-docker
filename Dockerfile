# ---------- Stage 1: Build environment ----------
FROM debian:bookworm AS builder

ENV OPENSSL_DIR=/opt/quictls \
    NGHTTP3_VER=v1.9.0 \
    NGTCP2_VER=v1.9.0

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

# ----- Build sfparse -----
WORKDIR /build/sfparse
RUN git clone https://github.com/ngtcp2/sfparse.git . && \
    mkdir -p /tmp/sfparse-copy && \
    cp sfparse.c /tmp/sfparse-copy/sfparse.c && \
    cp sfparse.h /tmp/sfparse-copy/sfparse.h && \
    autoreconf -fi && ./configure --prefix=/usr/local && make -j$(nproc) && make install

# ----- Build nghttp3 -----
WORKDIR /build/nghttp3
RUN git clone --branch ${NGHTTP3_VER} https://github.com/ngtcp2/nghttp3.git . && \
    mkdir -p lib/sfparse && \
    cp /tmp/sfparse-copy/sfparse.c lib/sfparse/sfparse.c && \
    cp /tmp/sfparse-copy/sfparse.h lib/sfparse/sfparse.h && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j$(nproc) && make install

# ----- Build quictls -----
WORKDIR /tmp/openssl
RUN git clone --depth 1 -b openssl-3.1.5+quic https://github.com/quictls/openssl.git . && \
    ./Configure enable-tls1_3 --prefix=${OPENSSL_DIR} linux-x86_64 && \
    make -j$(nproc) && make install && \
    echo "/opt/quictls/lib" > /etc/ld.so.conf.d/quictls.conf && \
    echo "/opt/quictls/lib64" >> /etc/ld.so.conf.d/quictls.conf && \
    ldconfig

# ✅ Copy .so for final image
RUN mkdir -p /usr/local/lib && \
    if [ -d /opt/quictls/lib ]; then cp -av /opt/quictls/lib/*.so* /usr/local/lib/; fi && \
    if [ -d /opt/quictls/lib64 ]; then cp -av /opt/quictls/lib64/*.so* /usr/local/lib/; fi

# ----- Build ngtcp2 -----
WORKDIR /build/ngtcp2
ENV PKG_CONFIG_PATH="${OPENSSL_DIR}/lib/pkgconfig"
RUN git clone --branch ${NGTCP2_VER} https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
        LDFLAGS="-Wl,-rpath,${OPENSSL_DIR}/lib" \
        --with-openssl=${OPENSSL_DIR} \
        --with-libnghttp3 \
        --enable-lib-only && \
    make -j$(nproc) && make install

# ----- Build Unbound -----
WORKDIR /build/unbound

ENV OPENSSL_CFLAGS="-I${OPENSSL_DIR}/include" \
    OPENSSL_LIBS="-L${OPENSSL_DIR}/lib -lssl -lcrypto -Wl,-rpath,${OPENSSL_DIR}/lib" \
    PKG_CONFIG_PATH="${OPENSSL_DIR}/lib/pkgconfig" \
    CPPFLAGS="-I${OPENSSL_DIR}/include" \
    CFLAGS="-I${OPENSSL_DIR}/include" \
    LDFLAGS="-L${OPENSSL_DIR}/lib -Wl,-rpath,${OPENSSL_DIR}/lib" \
    PATH="${OPENSSL_DIR}/bin:$PATH"

RUN git clone https://github.com/NLnetLabs/unbound.git . && \
    git checkout release-1.19.3 && \
    autoreconf -fi && \
    ./configure \
      --prefix=/usr/local \
      --with-libevent \
      --with-libngtcp2 \
      --with-libnghttp3 \
      --with-ssl=${OPENSSL_DIR} \
      --enable-dns-over-quic && \
    make -j$(nproc) && make install

# ---------- Stage 2: Final image (Alpine) ----------
FROM alpine:3.21

RUN apk add --no-cache libevent libcap expat libsodium libc6-compat libbsd

COPY --from=builder /usr/local /usr/local

ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
ENV LD_PRELOAD=/lib/libbsd.so
ENV PATH=/usr/local/sbin:$PATH

EXPOSE 853/udp 853/tcp 8853/udp

ENTRYPOINT ["/usr/local/sbin/unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
