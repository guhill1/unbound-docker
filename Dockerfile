# Stage 1: Build environment
FROM ubuntu:20.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    ca-certificates \
    wget \
    libtool \
    autoconf \
    automake \
    pkg-config \
    cmake \
    libevent-dev \
    libexpat1-dev \
    libsodium-dev \
    zlib1g-dev

# Install OpenSSL 3.1.5 (QUIC-supported from quictls)
RUN git clone --depth=1 -b openssl-3.1.5+quic https://github.com/quictls/openssl.git && \
    cd openssl && \
    ./Configure linux-x86_64 no-shared --prefix=/usr/local && \
    make -j$(nproc) && make install_sw

ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# Build nghttp3
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install

# Build ngtcp2
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local \
        --with-openssl=/usr/local \
        --with-libnghttp3=/usr/local \
        PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" && \
    make -j$(nproc) && make install

# Build Unbound 1.19.3
RUN git clone --branch release-1.19.3 --depth=1 https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
        --with-ssl=/usr/local \
        --with-libevent \
        --with-libnghttp3=/usr/local \
        --with-libngtcp2=/usr/local && \
    make -j$(nproc) && make install

# Stage 2: Runtime environment
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    libevent-2.1-7 \
    libexpat1 \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local /usr/local

# Set default command
ENTRYPOINT ["/usr/local/sbin/unbound"]
CMD ["-d", "-v"]
