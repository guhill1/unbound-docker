# Stage 1: Build everything
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    ca-certificates \
    git \
    wget \
    curl \
    libev-dev \
    libnghttp2-dev \
    libevent-dev \
    python3 \
    python3-pip

# ---------- Build OpenSSL (quictls fork) ----------
WORKDIR /opt
RUN git clone --depth=1 -b OpenSSL_1_1_1 https://github.com/quictls/openssl.git && \
    cd openssl && \
    ./config --prefix=/usr/local --openssldir=/usr/local/openssl && \
    make -j$(nproc) && \
    make install

ENV PATH="/usr/local/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

# ---------- Build nghttp3 ----------
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# ---------- Build ngtcp2 ----------
RUN git clone --recursive https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure \
        --enable-lib-only \
        --with-openssl=/usr/local \
        --with-libev \
        --with-nghttp3 && \
    make -j$(nproc) && \
    make install

# ---------- Build Unbound ----------
RUN git clone https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    git checkout release-1.19.3 && \
    autoreconf -fi && \
    ./configure \
        --with-ssl=/usr/local \
        --with-libevent \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-subnet \
        --enable-tfo-client \
        --enable-tfo-server \
        --enable-pthreads \
        --enable-ecdsa \
        --enable-ed25519 \
        --enable-ed448 \
        --enable-sha3 \
        --enable-quic && \
    make -j$(nproc) && \
    make install

# Stage 2: Final minimal image
FROM debian:stable-slim
COPY --from=builder /usr/local /usr/local

ENV LD_LIBRARY_PATH=/usr/local/lib
ENTRYPOINT ["/usr/local/sbin/unbound"]
CMD ["-d"]
