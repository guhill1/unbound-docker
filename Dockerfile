FROM alpine:latest AS builder

ENV CFLAGS="-I/usr/local/include"
ENV LDFLAGS="-L/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

RUN apk add --no-cache \
  build-base \
  autoconf \
  automake \
  libtool \
  git \
  cmake \
  libevent-dev \
  libexpat-dev \
  libsodium-dev \
  libcap \
  linux-headers \
  curl \
  openssl-dev

WORKDIR /build

# === Build and install quictls OpenSSL ===
RUN git clone --depth=1 -b OpenSSL_1_1_1w+quic https://github.com/quictls/openssl.git
WORKDIR /build/openssl
RUN ./config --prefix=/usr/local --openssldir=/usr/local/ssl no-shared && \
    make -j$(nproc) && make install_sw

# === Build and install sfparse ===
WORKDIR /build
RUN git clone --branch v1.9.0 https://github.com/ngtcp2/sfparse.git
WORKDIR /build/sfparse
RUN autoreconf -fi && ./configure --prefix=/usr/local && make -j$(nproc) && make install

# === Build and install nghttp3 ===
WORKDIR /build
RUN git clone https://github.com/ngtcp2/nghttp3.git
WORKDIR /build/nghttp3
RUN autoreconf -fi && ./configure --prefix=/usr/local && make -j$(nproc) && make install

# === Build and install ngtcp2 ===
WORKDIR /build
RUN git clone https://github.com/ngtcp2/ngtcp2.git
WORKDIR /build/ngtcp2
RUN autoreconf -fi && ./configure \
    --prefix=/usr/local \
    --enable-lib-only \
    --with-openssl=/usr/local \
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" && \
    make -j$(nproc) && make install

# === Build and install Unbound ===
WORKDIR /build
RUN git clone https://github.com/NLnetLabs/unbound.git
WORKDIR /build/unbound
RUN git checkout release-1.19.3 && \
    autoreconf -fi && \
    ./configure --prefix=/usr/local \
        --with-libexpat=/usr \
        --with-ssl=/usr/local \
        --with-libevent=/usr \
        --enable-dnscrypt \
        --enable-dns-over-tls \
        --enable-dns-over-https \
        --enable-dns-over-quic && \
    make -j$(nproc) && make install

# === Final image ===
FROM alpine:latest

RUN apk add --no-cache libevent libexpat libsodium

COPY --from=builder /usr/local /usr/local
ENV PATH="/usr/local/sbin:/usr/local/bin:$PATH"

ENTRYPOINT ["unbound"]
CMD ["-d", "-c", "/etc/unbound/unbound.conf"]
