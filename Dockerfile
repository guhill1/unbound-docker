FROM ubuntu:22.04

# 设置非交互式模式，避免在安装过程中等待用户输入
ENV DEBIAN_FRONTEND=noninteractive

# 更新系统并安装必要的构建工具
RUN apt update && apt install -y \
    git build-essential autoconf automake libtool \
    libevent-dev libssl-dev libexpat1-dev \
    libnghttp3-dev libngtcp2-dev \
    ca-certificates curl \
    && update-ca-certificates

# 克隆仓库并切换到指定分支
RUN git clone https://github.com/NLnetLabs/unbound.git /build/unbound && \
    cd /build/unbound && \
    git checkout release-1.19.3

# 运行 autogen.sh
RUN chmod +x /build/unbound/autogen.sh && /build/unbound/autogen.sh

# 配置编译选项
RUN /build/unbound/configure --enable-dns-over-quic \
      --with-libevent \
      --with-ssl \
      --with-libnghttp3 \
      --with-libngtcp2 \
      --disable-shared

# 编译
RUN make -C /build/unbound -j$(nproc)

# 安装
RUN make -C /build/unbound install

# 清理
RUN rm -rf /build/unbound

# 添加配置和证书文件
COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

EXPOSE 53/udp

CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
