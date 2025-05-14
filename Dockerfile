FROM alpine:3.20 as builder

ENV OPENSSL_DIR=/opt/quictls \
    NGHTTP3_VER=v1.3.0 \
    NGTCP2_VER=v1.9.0 \
    UNBOUND_VER=1.19.3

RUN apk add --no-cache \
    build-base \
    git \
    autoconf \
    automake \
    libtool \
    pkgconfig \
    libevent-dev \
    expat-dev \
    libsodium-dev \
    linux-headers \
    cmake \
    doxygen \
    python3 \
    py3-sphinx \
    py3-sphinx_rtd_theme \
    py3-docutils

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

# ---------- Build ngtcp2 ----------
WORKDIR /build/ngtcp2
RUN git clone --branch ${NGTCP2_VER} https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
        PKG_CONFIG_PATH="${OPENSSL_DIR}/lib/pkgconfig" \
        LDFLAGS="-Wl,-rpath,${OPENSSL_DIR}/lib" \
        --with-openssl \
        --with-libnghttp3 \
        --enable-lib-only && \
    make -j$(nproc) && make install

# ---------- Build Unbound ----------
WORKDIR /build/unbound
RUN git clone --branch release-${UNBOUND_VER} https://github.com/NLnetLabs/unbound.git . && \
    ./configure --prefix=/opt/unbound \
        --with-ssl=${OPENSSL_DIR} \
        --with-libevent \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-subnet \
        --enable-tfo-client \
        --enable-tfo-server \
        --enable-ecdsa \
        --enable-ed25519 \
        --enable-ed448 \
        --enable-doq && \
    make -j$(nproc) && make install

# ---------- Runtime image ----------
FROM alpine:3.20
COPY --from=builder /opt/unbound /opt/unbound
COPY --from=builder /opt/quictls /opt/quictls
COPY --from=builder /usr/local /usr/local

RUN apk add --no-cache libevent expat libsodium && \
    mkdir -p /etc/unbound && \
    ln -s /opt/unbound/sbin/unbound /usr/sbin/unbound

ENTRYPOINT ["/opt/unbound/sbin/unbound", "-d"]
