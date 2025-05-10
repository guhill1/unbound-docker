# 使用 Ubuntu 基础镜像
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

# 克隆仓库
RUN git clone https://github.com/NLnetLabs/unbound.git

# 切换到指定版本
WORKDIR /build/unbound
RUN git checkout release-1.19.3

# 运行 autogen.sh
RUN chmod +x ./autogen.sh && ./autogen.sh

# 配置编译选项
RUN ./configure --enable-dns-over-quic \
      --with-libevent \
      --with-ssl \
      --with-libnghttp3 \
      --with-libngtcp2 \
      --disable-shared

# 编译
RUN make -j$(nproc)

# 安装
RUN make install

# 清理
WORKDIR /build
RUN rm -rf unbound

# 添加配置和证书文件
COPY unbound.conf /etc/unbound/unbound.conf
COPY unbound_server.key /etc/unbound/unbound_server.key
COPY unbound_server.pem /etc/unbound/unbound_server.pem

EXPOSE 53/udp

CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
