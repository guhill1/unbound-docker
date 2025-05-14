# -------- stage 1: builder --------
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
    libexpat-dev \
    libsodium-dev \
    pkgconfig \
    libcap \
    linux-headers \
    cmake

WORKDIR /build

# -------- OpenSSL (QUIC-enabled, use quictls fork) --------
RUN git clone --depth=1 -b OpenSSL_1_1_1u+quic https://github.com/quictls/openssl.git
WORKDIR /build/openssl
RUN ./Configure linux-x86_64 no-shared --prefix=/usr/local && \
    make -j$(nproc) && make install_sw

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV LD_LIBRARY_PATH=/usr/local/lib

# -------- Build sfparse --------
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/sfparse.git
WORKDIR /build/sfparse
RUN autoreconf -i && ./configure --prefix=/usr/local && make -j$(nproc) && make install

# -------- Build nghttp3 --------
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git
WORKDIR /build/nghttp3
RUN autoreconf -i && ./configure --prefix=/usr/local && make -j$(nproc) && make install

# -------- Build ngtcp2 --------
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git
WORKDIR /build/ngtcp2
RUN autoreconf -i && ./configure --prefix=/usr/local \
    --with-openssl --with-libnghttp3 --with-sfparse && \
    make -j$(nproc) && make install

# -------- Build Unbound --------
WORKDIR /build
RUN wget https://www.nlnetlabs.nl/downloads/unbound/unbound-1.19.3.tar.gz && \
    tar -xf unbound-1.19.3.tar.gz
WORKDIR /build/unbound-1.19.3
RUN ./configure --prefix=/opt/unbound \
    --with-ssl=/usr/local \
    --with-libevent \
    --with-libexpat \
    --enable-dnscrypt \
    --enable-dnstap \
    --enable-subnet \
    --enable-tfo-client \
    --enable-tfo-server \
    --enable-ecdsa \
    --enable-ed25519 \
    --enable-ed448 \
    --enable-quic \
    --with-libngtcp2=/usr/local \
    --with-libnghttp3=/usr/local && \
    make -j$(nproc) && make install

# -------- stage 2: runtime --------
FROM alpine:3.19

RUN apk add --no-cache \
    libevent \
    expat \
    libsodium \
    ca-certificates

COPY --from=builder /opt/unbound /opt/unbound
COPY --from=builder /usr/local /usr/local

ENV PATH="/opt/unbound/sbin:$PATH"

ENTRYPOINT ["unbound"]
CMD ["-d"]
