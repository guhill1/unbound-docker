# Stage 1: Build environment
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    ca-certificates \
    cmake \
    ninja-build \
    pkg-config \
    libtool \
    autoconf \
    automake \
    libevent-dev \
    libexpat1-dev \
    libssl-dev \
    libsodium-dev

# =====================
# Build quictls (OpenSSL with QUIC support)
# =====================
WORKDIR /quictls
RUN git clone --depth=1 -b OpenSSL_1_1_1u+quic https://github.com/quictls/openssl.git
WORKDIR /quictls/openssl
RUN ./config no-shared --prefix=/usr/local && make -j$(nproc) && make install_sw

ENV PATH="/usr/local/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
ENV CFLAGS="-I/usr/local/include"
ENV LDFLAGS="-L/usr/local/lib"

# =====================
# Build sfparse
# =====================
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/sfparse.git
WORKDIR /build/sfparse
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j$(nproc) && \
    cmake --install build --prefix /usr/local

# =====================
# Build nghttp3
# =====================
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git
WORKDIR /build/nghttp3
RUN autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# =====================
# Build ngtcp2
# =====================
WORKDIR /build
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git
WORKDIR /build/ngtcp2
RUN autoreconf -i && \
    ./configure --prefix=/usr/local \
    --with-openssl=/usr/local \
    --with-nghttp3=/usr/local && \
    make -j$(nproc) && \
    make install

# =====================
# Build Unbound with DoQ support
# =====================
WORKDIR /build
RUN wget https://www.nlnetlabs.nl/downloads/unbound/unbound-1.19.3.tar.gz && \
    tar -xzf unbound-1.19.3.tar.gz
WORKDIR /build/unbound-1.19.3
RUN ./configure --prefix=/opt/unbound \
    --with-libevent \
    --with-ssl=/usr/local \
    --enable-dnscrypt \
    --enable-dnstap \
    --enable-tfo-client \
    --enable-tfo-server \
    --enable-subnet \
    --enable-cachedb \
    --enable-pie \
    --enable-relro-now \
    --enable-dns-over-quic && \
    make -j$(nproc) && \
    make install

# Stage 2: Runtime image
FROM ubuntu:22.04 AS runtime

COPY --from=builder /opt/unbound /opt/unbound

ENV PATH="/opt/unbound/sbin:$PATH"

# Copy necessary libraries from builder
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/local/include /usr/local/include

# Make sure dynamic linker finds the libraries
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

CMD ["unbound", "-d", "-c", "/opt/unbound/etc/unbound/unbound.conf"]
