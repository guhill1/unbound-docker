# ============================
# Stage 1: Build dependencies
# ============================
FROM alpine:3.20 AS builder

RUN apk add --no-cache \
    autoconf automake libtool build-base \
    git openssl-dev c-ares-dev \
    libevent-dev libcap-dev \
    linux-headers cmake bash \
    libstdc++ util-linux-dev

WORKDIR /build

# 下载并手动复制 sfparse 文件
RUN wget https://raw.githubusercontent.com/ngtcp2/sfparse/main/sfparse.c -O /usr/include/sfparse/sfparse.c \
    && wget https://raw.githubusercontent.com/ngtcp2/sfparse/main/sfparse.h -O /usr/include/sfparse/sfparse.h

# --- Build nghttp3 ---
WORKDIR /build/nghttp3
RUN git clone https://github.com/ngtcp2/nghttp3 . \
    && autoreconf -i \
    && ./configure --prefix=/usr \
    && make -j$(nproc) \
    && make install

# --- Build ngtcp2 ---
WORKDIR /build/ngtcp2
RUN git clone https://github.com/ngtcp2/ngtcp2 . \
    && autoreconf -i \
    && ./configure --prefix=/usr --enable-lib-only \
    && make -j$(nproc) \
    && make install

# --- Build Unbound ---
WORKDIR /build/unbound
RUN git clone https://github.com/NLnetLabs/unbound . \
    && cd unbound \
    && git checkout release-1.20.0 \
    && ./autogen.sh \
    && ./configure --prefix=/usr \
        --with-ssl=/usr \
        --with-libevent=/usr \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-dns-over-quic \
        --with-nghttp3=/usr \
        --with-ngtcp2=/usr \
    && make -j$(nproc) \
    && make install

# =============================
# Stage 2: Final minimal image
# =============================
FROM alpine:3.20

RUN apk add --no-cache libevent openssl libstdc++

COPY --from=builder /usr /usr

ENTRYPOINT ["unbound", "-d"]
