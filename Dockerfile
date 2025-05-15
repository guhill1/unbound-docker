# ======================================
# Stage 1: Build OpenSSL (quictls)
# ======================================
FROM alpine:3.20 AS quictls
RUN apk add --no-cache build-base perl git

ARG OPENSSL_VER=openssl-3.1.5+quic
ARG OPENSSL_DIR=/opt/quictls
WORKDIR /build/quictls

RUN git clone --depth 1 -b ${OPENSSL_VER} https://github.com/quictls/openssl.git . && \
    ./Configure enable-tls1_3 --prefix=${OPENSSL_DIR} linux-x86_64 && \
    make -j$(nproc) && make install

# ======================================
# Stage 2: Build nghttp3/ngtcp2/sfparse
# ======================================
FROM alpine:3.20 AS deps
RUN apk add --no-cache build-base cmake git

ARG INSTALL_DIR=/opt/deps
WORKDIR /build

# nghttp3
RUN git clone --depth 1 https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    cmake -B build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -DCMAKE_BUILD_TYPE=Release . && \
    cmake --build build -j$(nproc) && \
    cmake --install build

# ngtcp2 + sfparse
RUN git clone --depth 1 https://github.com/ngtcp2/ngtcp2.git && \
    git clone --depth 1 https://github.com/yuis-ice/sfparse.git && \
    cp sfparse/sfparse.[ch] ngtcp2/lib/ && \
    cd ngtcp2 && \
    cmake -B build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_SHARED_LIB=OFF \
        -DENABLE_LIB_ONLY=ON \
        -DENABLE_EXAMPLES=OFF \
        -DENABLE_SERVER=OFF \
        -DENABLE_CLIENT=OFF \
        . && \
    cmake --build build -j$(nproc) && \
    cmake --install build

# ======================================
# Stage 3: Build Unbound
# ======================================
FROM alpine:3.20 AS unbound
RUN apk add --no-cache build-base libevent-dev expat-dev libsodium-dev git autoconf automake libtool

ARG UNBOUND_VER=1.19.3
WORKDIR /build/unbound
RUN git clone --branch release-${UNBOUND_VER} --depth 1 https://github.com/NLnetLabs/unbound.git . && \
    sh autogen.sh

# Copy deps from previous stages
COPY --from=quictls /opt/quictls /opt/quictls
COPY --from=deps /opt/deps /opt/deps

# Set env
ENV LDFLAGS="-L/opt/quictls/lib -L/opt/quictls/lib64 -L/opt/deps/lib"
ENV CPPFLAGS="-I/opt/quictls/include -I/opt/deps/include"
ENV PKG_CONFIG_PATH="/opt/quictls/lib/pkgconfig:/opt/deps/lib/pkgconfig"

RUN ./configure --prefix=/opt/unbound \
    --with-ssl=/opt/quictls \
    --with-libevent --with-libexpat --with-pthreads \
    --enable-dnscrypt \
    --enable-tfo-client \
    --enable-dns-over-tls \
    --enable-dns-over-quic \
    --with-libngtcp2=/opt/deps \
    --with-libnghttp3=/opt/deps \
    --disable-shared && \
    make -j$(nproc) && \
    make install

# ======================================
# Stage 4: Runtime
# ======================================
FROM alpine:3.20
RUN apk add --no-cache libevent libsodium expat

COPY --from=quictls /opt/quictls /opt/quictls
COPY --from=unbound /opt/unbound /opt/unbound

ENV LD_LIBRARY_PATH="/opt/quictls/lib:/opt/quictls/lib64"

ENTRYPOINT ["/opt/unbound/sbin/unbound"]
