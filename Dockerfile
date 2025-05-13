# syntax=docker/dockerfile:1

# ========= 构建阶段 =========
FROM ubuntu:22.04 AS builder

# 设置非交互模式防止 tzdata 卡住
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    ca-certificates \
    git \
    curl \
    libssl-dev \
    libevent-dev \
    libcap-dev \
    bash \
    libc-ares-dev \
    libnghttp2-dev \
    libprotobuf-c-dev \
    protobuf-c-compiler \
    libev-dev \
    libyaml-dev \
    libexpat1-dev \
    doxygen \
    python3-sphinx \
    cmake \
    ninja-build \
    clang \
    zlib1g-dev \
    wget \
    libuv1-dev \
    linux-headers-generic \
    && ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/ngtcp2/nghttp3.git
WORKDIR /nghttp3
RUN autoreconf -i && ./configure --prefix=/usr && make -j$(nproc) && make install

RUN git clone --depth=1 https://github.com/ngtcp2/ngtcp2.git
WORKDIR /ngtcp2
RUN autoreconf -i && ./configure --prefix=/usr && make -j$(nproc) && make install

RUN git clone --depth=1 https://github.com/NLnetLabs/unbound.git
WORKDIR /unbound
RUN ./autogen.sh && \
    ./configure --prefix=/opt/unbound \
                --enable-dns-over-quic \
                --with-ssl \
                --with-libnghttp2 \
                --with-libevent \
                --with-libev \
                --with-libngtcp2 && \
    make -j$(nproc) && make install

# ========= 运行阶段 =========
FROM ubuntu:22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    libevent-dev \
    libssl-dev \
    libcap2 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/unbound /opt/unbound

ENV PATH="/opt/unbound/sbin:$PATH"

CMD ["unbound", "-d"]
