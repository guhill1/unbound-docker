# -------- Stage 1: Build everything --------
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    build-essential \
    autoconf automake libtool pkg-config \
    git curl ca-certificates \
    libevent-dev libexpat1-dev \
    libyaml-dev libsodium-dev

# ---- Install OpenSSL (quictls branch) ----
WORKDIR /build/openssl
RUN git clone --depth=1 -b OpenSSL_1_1_1w+quic https://github.com/quictls/openssl.git . && \
    ./config --prefix=/usr/local --openssldir=/usr/local/ssl && \
    make -j$(nproc) && make install

ENV PATH="/usr/local/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib"

# ---- Build and install sfparse ----
WORKDIR /build/sfparse
RUN git clone https://github.com/ngtcp2/sfparse.git . && \
    autoreconf -i && ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install

# ---- Build and install nghttp3 ----
WORKDIR /build/nghttp3
RUN git clone --branch v1.9.0 https://github.com/ngtcp2/nghttp3.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install

# ---- Build and install ngtcp2 ----
WORKDIR /build/ngtcp2
RUN git clone --branch v1.9.0 https://github.com/ngtcp2/ngtcp2.git . && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
        PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" \
        --with-openssl=/usr/local \
        --with-libnghttp3=/usr/local \
        --with-libsfparse=/usr/local && \
    make -j$(nproc) && make install

# ---- Build and install Unbound (QUIC support) ----
WORKDIR /build/unbound
RUN git clone https://github.com/NLnetLabs/unbound.git . && \
    git checkout release-1.19.3 && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-subnet \
        --with-libevent \
        --with-ssl=/usr/local \
        --with-libngtcp2=/usr/local \
        --with-libnghttp3=/usr/local && \
    make -j$(nproc) && make install

# -------- Stage 2: Minimal runtime image --------
FROM debian:bullseye-slim

COPY --from=builder /usr/local /usr/local
ENV LD_LIBRARY_PATH="/usr/local/lib"

ENTRYPOINT ["/usr/local/sbin/unbound"]
CMD ["-d"]
