# 使用最新的 Alpine 镜像
FROM alpine:latest

# 安装依赖
RUN apk add --no-cache \
    git \
    autoconf \
    automake \
    libtool \
    gcc \
    g++ \
    make \
    bash \
    libevent-dev \
    libssl-dev \
    libnghttp3-dev \
    libngtcp2-dev

# 克隆 Unbound 源码并切换到指定版本
RUN git clone https://github.com/NLnetLabs/unbound.git /build/unbound && \
    cd /build/unbound && \
    git checkout release-1.19.3

# 确保工作目录正确
WORKDIR /build/unbound

# 如果存在 autogen.sh，运行它；否则直接配置
RUN if [ -f /build/unbound/autogen.sh ]; then \
        chmod +x /build/unbound/autogen.sh && /build/unbound/autogen.sh; \
    else \
        cd /build/unbound && \
        ./configure --enable-dns-over-quic \
                    --with-libevent \
                    --with-ssl \
                    --with-libnghttp3 \
                    --with-libngtcp2 \
                    --disable-shared; \
    fi

# 编译并安装
RUN make -j$(nproc) && make install

# 清理构建文件
RUN cd / && rm -rf /build/unbound

# 配置 Unbound，复制配置文件和证书
COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

# 设置默认命令运行 Unbound
CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
