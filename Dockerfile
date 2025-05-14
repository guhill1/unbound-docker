FROM alpine:3.19 as builder

RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    git \
    cmake \
    perl \
    wget \
    curl \
    linux-headers \
    libevent-dev \
    expat-dev \
    libsodium-dev \
    pkgconfig

WORKDIR /build

# === Build quictls (OpenSSL with QUIC support) ===
RUN git clone --depth=1 -b OpenSSL_1_1_1q+quic https://github.com/quictls/openssl.git && \
    cd openssl && \
    ./config enable-tls1_3 --prefix=/usr/local && \
    make -j$(nproc) && \
    make install_sw

# === Build nghttp3 ===
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# === Build ngtcp2 ===
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
      PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" \
      --with-openssl=/usr/local && \
    make -j$(nproc) && \
    make install

# === Build sfparse (manual step) ===
WORKDIR /build/sfparse
RUN git clone --depth=1 https://github.com/ngtcp2/sfparse.git . && \
    gcc -c -O2 -fPIC sfparse.c && \
    ar rcs libsfparse.a sfparse.o && \
    cp sfparse.h /usr/local/include/ && \
    cp libsfparse.a /usr/local/lib/

# === Build Unbound ===
WORKDIR /build
RUN git clone --depth=1 --branch release-1.19.3 https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
      --with-ssl=/usr/local \
      --with-libevent=/usr \
      --enable-dns-over-quic \
      --with-libngtcp2=/usr/local \
      --with-libnghttp3=/usr/local && \
    make -j$(nproc) && \
    make install

# === Runtime image ===
FROM alpine:3.19 as unbound-runtime

RUN apk add --no-cache libevent libsodium expat

COPY --from=builder /usr/local /usr/local

# Create basic config dir
RUN mkdir -p /etc/unbound

ENTRYPOINT ["/usr/local/sbin/unbound"]
CMD ["-d", "-c", "/etc/unbound/unbound.conf"]
