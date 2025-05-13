# Stage 1: Build dependencies
FROM ubuntu:20.04 as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    git \
    libtool \
    autoconf \
    automake \
    pkg-config \
    libssl-dev \
    libexpat1-dev \
    libevent-dev \
    libsodium-dev \
    cmake \
    gcc \
    g++ \
    make \
    curl \
    zlib1g-dev \
    ca-certificates

# Install OpenSSL 3.1.5 (with QUIC support)
RUN wget https://www.openssl.org/source/openssl-3.1.5.tar.gz && \
    tar -xf openssl-3.1.5.tar.gz && \
    cd openssl-3.1.5 && \
    ./Configure linux-x86_64 enable-tls1_3 no-shared --prefix=/usr/local && \
    make -j$(nproc) && make install_sw

# Install nghttp3 dependencies (sfparse.h and sfparse.c)
RUN git clone https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# Stage 2: Runtime image
FROM ubuntu:20.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl1.1 \
    libexpat1 \
    libevent \
    ca-certificates

# Copy the build artifacts from the builder stage
COPY --from=builder /usr/local /usr/local

# Set up the entrypoint (replace with your actual application setup)
ENTRYPOINT ["/bin/bash"]
