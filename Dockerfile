# ---------- Stage 1: build dependencies ----------
FROM alpine:3.19 AS builder

RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    git \
    wget \
    curl \
    openssl-dev \
    libevent-dev \
    libsodium-dev \
    pkgconfig \
    libcap \
    linux-headers \
    cmake \
    expat-dev

WORKDIR /build

# ---------- Build sfparse ----------
WORKDIR /build/sfparse
RUN git clone --depth=1 https://github.com/ngtcp2/sfparse.git . && \
    gcc -c -O2 -fPIC sfparse.c && \
    ar rcs libsfparse.a sfparse.o && \
    mkdir -p /usr/local/include/sfparse && \
    cp sfparse.h /usr/local/include/sfparse/ && \
    cp libsfparse.a /usr/local/lib/

# ---------- Build nghttp3 ----------
WORKDIR /build/nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# ---------- Build ngtcp2 ----------
WORKDIR /build/ngtcp2
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local --with-libnghttp3=/usr/local && \
    make -j$(nproc) && \
    make install

# ---------- Build latest OpenSSL with QUIC ----------
WORKDIR /build/openssl
RUN git clone --depth=1 -b openssl-3.1.5 https://github.com/quictls/openssl.git . && \
    ./Configure enable-tls1_3 --prefix=/usr/local --openssldir=/usr/local/ssl linux-x86_64 && \
    make -j$(nproc) && \
    make install_sw

# ---------- Build Unbound ----------
WORKDIR /build/unbound
RUN git clone --depth=1 -b release-1.19.3 https://github.com/NLnetLabs/unbound.git . && \
    ./autogen.sh && \
    ./configure --prefix=/usr/local \
        --with-ssl=/usr/local \
        --with-libevent=/usr \
        --enable-dnscrypt \
        --enable-dns-over-tls \
        --enable-dns-over-quic \
        --with-libngtcp2=/usr/local \
        --with-libnghttp3=/usr/local && \
    make -j$(nproc) && \
    make install

# ---------- Stage 2: Final runtime image ----------
FROM alpine:3.19

RUN apk add --no-cache libevent openssl libsodium expat

COPY --from=builder /usr/local /usr/local

ENTRYPOINT ["/usr/local/sbin/unbound"]
CMD ["-d", "-c", "/etc/unbound/unbound.conf"]
