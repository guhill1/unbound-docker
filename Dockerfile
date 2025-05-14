# Stage 1: Build dependencies
FROM ubuntu:20.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    git \
    libtool \
    autoconf \
    automake \
    pkg-config \
    cmake \
    gcc \
    g++ \
    make \
    curl \
    zlib1g-dev \
    ca-certificates \
    libevent-dev \
    libexpat1-dev \
    libsodium-dev

# OpenSSL 3.1.5 (QUIC supported)
RUN wget https://www.openssl.org/source/openssl-3.1.5.tar.gz && \
    tar -xf openssl-3.1.5.tar.gz && \
    cd openssl-3.1.5 && \
    ./Configure linux-x86_64 enable-tls1_3 enable-quic no-shared --prefix=/usr/local && \
    make -j$(nproc) && make install_sw

ENV PATH="/usr/local/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

# Clone and prepare sfparse (needed by nghttp3)
RUN git clone https://github.com/h2o/sfparse.git /tmp/sfparse && \
    mkdir -p /tmp/nghttp3/ext/sfparse && \
    cp /tmp/sfparse/include/sfparse.h /tmp/nghttp3/ext/sfparse/ && \
    cp /tmp/sfparse/sfparse.c /tmp/nghttp3/ext/sfparse/

# Clone and build nghttp3 (QUIC lib)
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git /tmp/nghttp3 && \
    cd /tmp/nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install

# Clone and build ngtcp2 (depends on nghttp3 & OpenSSL)
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git /tmp/ngtcp2 && \
    cd /tmp/ngtcp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local \
        --with-openssl \
        --with-libnghttp3=/usr/local && \
    make -j$(nproc) && make install

# Build Unbound with QUIC support
RUN wget https://nlnetlabs.nl/downloads/unbound/unbound-1.19.3.tar.gz && \
    tar -xzf unbound-1.19.3.tar.gz && \
    cd unbound-1.19.3 && \
    ./configure --prefix=/usr/local \
        --with-libevent \
        --with-libnghttp3=/usr/local \
        --with-libngtcp2=/usr/local \
        --with-ssl=/usr/local && \
    make -j$(nproc) && make install

# Stage 2: Runtime
FROM ubuntu:20.04

RUN apt-get update && apt-get install -y \
    libevent-2.1-7 \
    libexpat1 \
    libsodium23 \
    ca-certificates

COPY --from=builder /usr/local /usr/local

ENV PATH="/usr/local/sbin:/usr/local/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib"

CMD ["unbound", "-d"]
