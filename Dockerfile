# ============================
# Stage 1: Build dependencies
# ============================
FROM alpine:3.20 AS builder

# 安装必要的工具，包括 wget
RUN apk add --no-cache \
    wget \
    autoconf automake libtool build-base \
    git openssl-dev c-ares-dev \
    libevent-dev libcap-dev \
    linux-headers cmake bash \
    libstdc++ util-linux-dev

WORKDIR /build

# 下载并手动复制 sfparse 文件
RUN wget https://raw.githubusercontent.com/ngtcp2/sfparse/main/sfparse.c -O /usr/include/sfparse/sfparse.c \
    && wget https://raw.githubusercontent.com/ngtcp2/sfparse/main/sfparse.h -O /usr/include/sfparse/sfparse.h

# 继续后续构建步骤...
