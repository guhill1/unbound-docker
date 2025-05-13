# Stage 1: Build environment
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    build-essential \
    git \
    curl \
    ca-certificates \
    pkg-config \
    libtool \
    autoconf \
    automake \
    libev-dev \
    libevent-dev \
    libnghttp2-dev \
    libunistring-dev \
    libyaml-dev \
    libexpat1-dev \
    cmake \
    libssl-dev \
    wget \
    python3 \
    python3-pip

WORKDIR /opt

# Build OpenSSL 3.1+ with QUIC support
RUN wget https://www.openssl.org/source/openssl-3.1.5.tar.gz && \
    tar -xf openssl-3.1.5.tar.gz && \
    cd openssl-3.1.5 && \
    ./Configure linux-x86_64 enable-tls1_3 enable-quic no-shared --prefix=/usr/local && \
    make -j$(nproc) && make install_sw

ENV PATH="/usr/local/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

# Build sfparse
RUN git clone https://github.com/ngtcp2/sfparse.git && \
    cd sfparse && \
    autoreconf -i && ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install

# Build nghttp3
RUN git clone https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install

# Build ngtcp2
RUN git clone --recursive https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --enable-lib-only \
        --with-openssl --with-libev --with-nghttp3 \
        --prefix=/usr/local && \
    make -j$(nproc) && make install

# Build Unbound with QUIC
RUN wget https://www.nlnetlabs.nl/downloads/unbound/unbound-1.19.3.tar.gz && \
    tar -xzf unbound-1.19.3.tar.gz && \
    cd unbound-1.19.3 && \
    ./configure --prefix=/usr/local \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-subnet \
        --enable-tfo-client \
        --enable-tfo-server \
        --with-libevent \
        --with-ssl=/usr/local \
        --with-libngtcp2 && \
    make -j$(nproc) && make install

# Stage 2: Runtime image
FROM debian:bullseye-slim AS runtime

RUN apt update && apt install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local /usr/local

ENTRYPOINT ["unbound"]
