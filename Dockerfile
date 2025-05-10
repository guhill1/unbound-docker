FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    git build-essential autoconf automake libtool \
    libevent-dev libssl-dev libexpat1-dev \
    libnghttp3-dev libngtcp2-dev \
    ca-certificates curl && \
    update-ca-certificates

WORKDIR /build
RUN git clone https://github.com/NLnetLabs/unbound.git && \
    cd unbound && \
    git checkout release-1.19.3 && \
    ./autogen.sh && \
    ./configure \
      --enable-dns-over-quic \
      --with-libevent \
      --with-ssl \
      --with-libnghttp3 \
      --with-libngtcp2 \
      --disable-shared && \
    make -j$(nproc) && \
    make install && \
    cd .. && rm -rf unbound

# 配置拷贝
COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

EXPOSE 53/udp

CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
