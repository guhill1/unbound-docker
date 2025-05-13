FROM alpine:3.18 as builder

# 安装构建依赖
RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    git \
    cmake \
    openssl-dev \
    libev-dev \
    libevent-dev \
    linux-headers \
    pkgconf \
    doxygen \
    bash \
    zlib-dev \
    util-linux-dev \
    libcap \
    libcap-dev

WORKDIR /opt

# ---------- Build nghttp3 ----------
RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git

# ---------- Build sfparse ----------
RUN git clone --depth=1 https://github.com/ngtcp2/sfparse.git && \
    cd sfparse && \
    autoreconf -i && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# ---------- Build ngtcp2 ----------
RUN git clone --recursive https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    autoreconf -i && \
    ./configure --enable-lib-only \
        --with-openssl \
        --with-libev \
        --with-nghttp3 \
        --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

# ---------- Build unbound ----------
RUN git clone --depth=1 https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    autoreconf -fi && \
    ./configure --prefix=/opt/unbound \
        --enable-dnscrypt \
        --enable-dnstap \
        --enable-subnet \
        --enable-tfo-client \
        --enable-tfo-server \
        --enable-pie \
        --enable-relro-now \
        --enable-shared \
        --enable-static \
        --with-libevent \
        --with-ssl=/usr && \
    make -j$(nproc) && \
    make install

# ---------- Final Stage ----------
FROM alpine:3.18

RUN apk add --no-cache libevent openssl libcap

COPY --from=builder /opt/unbound /opt/unbound
COPY --from=builder /usr/local/lib/libngtcp2*.so* /usr/local/lib/
COPY --from=builder /usr/local/lib/libnghttp3*.so* /usr/local/lib/
COPY --from=builder /usr/local/lib/libev.so* /usr/local/lib/
COPY --from=builder /usr/local/lib/libsfparse.so* /usr/local/lib/

ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PATH="/opt/unbound/sbin:$PATH"

ENTRYPOINT ["unbound"]
CMD ["-d", "-c", "/opt/unbound/etc/unbound/unbound.conf"]
