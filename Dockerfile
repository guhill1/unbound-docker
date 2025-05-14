FROM alpine:3.21 AS builder

RUN apk add --no-cache \
    build-base autoconf automake libtool git cmake \
    libevent-dev expat-dev libsodium-dev libcap linux-headers curl pkgconf

WORKDIR /build

# ===== Build quictls (OpenSSL with QUIC support) =====
RUN git clone --depth=1 -b OpenSSL_1_1_1u+quic https://github.com/quictls/openssl.git && \
    cd openssl && \
    ./config --prefix=/usr/local --openssldir=/usr/local/ssl enable-tls1_3 enable-ec_nistp_64_gcc_128 no-shared && \
    make -j$(nproc) && make install_sw

ENV PATH="/usr/local/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

# ===== Build sfparse =====
WORKDIR /build/sfparse
RUN git clone https://github.com/ngtcp2/sfparse.git . && \
    autoreconf -fi && ./configure --prefix=/usr/local && make -j$(nproc) && make install

# ===== Build nghttp3 =====
WORKDIR /build/nghttp3
RUN git clone --branch v1.9.0 https://github.com/ngtcp2/nghttp3.git . && \
    mkdir -p lib/sfparse && \
    cp /usr/local/include/sfparse.h lib/sfparse/sfparse.h && \
    cp /usr/local/lib/libsfparse.a . && \
    # 若 sfparse.c 存在，复制它；否则跳过
    test -f /usr/local/src/sfparse/sfparse.c && cp /usr/local/src/sfparse/sfparse.c lib/sfparse/sfparse.c || true && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --enable-lib-only && \
    make -j$(nproc) && make install

# ===== Build ngtcp2 =====
WORKDIR /build/ngtcp2
RUN git clone --branch v1.6.0 https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
        --with-openssl=/usr/local \
        --with-nghttp3=/usr/local \
        PKG_CONFIG_PATH=$PKG_CONFIG_PATH && \
    make -j$(nproc) && make install

# ===== Build Unbound with DNS-over-QUIC =====
WORKDIR /build/unbound
RUN git clone --branch release-1.19.3 https://github.com/NLnetLabs/unbound.git . && \
    autoreconf -fi && \
    ./configure --prefix=/opt/unbound \
        --with-ssl=/usr/local \
        --with-libevent \
        --with-libnghttp3=/usr/local \
        --with-libngtcp2=/usr/local \
        --enable-dns-over-quic && \
    make -j$(nproc) && make install

# ===== Runtime stage =====
FROM alpine:3.21
RUN apk add --no-cache libevent openssl libsodium expat

COPY --from=builder /opt/unbound /opt/unbound
COPY unbound.conf /etc/unbound/unbound.conf

ENV PATH="/opt/unbound/sbin:$PATH"

ENTRYPOINT ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
