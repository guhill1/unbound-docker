# Stage 1: Build stage
FROM ubuntu:20.04 as builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
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
    python3 \
    python3-pip

# Install OpenSSL 3.1.5 with QUIC support
RUN wget https://www.openssl.org/source/openssl-3.1.5.tar.gz && \
    tar -xf openssl-3.1.5.tar.gz && \
    cd openssl-3.1.5 && \
    ./Configure linux-x86_64 --prefix=/usr/local/openssl --libdir=lib no-shared && \
    make -j$(nproc) && make install_sw

ENV PATH="/usr/local/openssl/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/openssl/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig:$PKG_CONFIG_PATH"

# Build nghttp3 (needs sfparse.h/c)
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install

# Build ngtcp2
RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local --with-openssl=/usr/local/openssl --enable-lib-only && \
    make -j$(nproc) && make install

# Build Unbound with DoQ support
RUN git clone https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    git checkout release-1.19.3 && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local/unbound \
        --with-ssl=/usr/local/openssl \
        --with-libexpat=/usr \
        --with-libevent=/usr \
        --enable-dns-over-quic && \
    make -j$(nproc) && make install

# Stage 2: Runtime image
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libevent-2.1-7 \
    libexpat1 \
    ca-certificates

# Copy binaries and libraries from build stage
COPY --from=builder /usr/local/openssl /usr/local/openssl
COPY --from=builder /usr/local/unbound /usr/local/unbound
COPY --from=builder /usr/local/lib /usr/local/lib

ENV PATH="/usr/local/unbound/sbin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/openssl/lib:/usr/local/lib:$LD_LIBRARY_PATH"

EXPOSE 853/udp

CMD ["unbound", "-d"]
