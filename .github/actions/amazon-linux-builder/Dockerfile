FROM amazonlinux:2023

# Set environment variables to prevent TTY issues during build
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=dumb

ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.2

# Set locale early to prevent encoding issues
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:"
ENV LC_ALL=en_US.UTF-8

RUN yum update -y
RUN yum install -y tar wget git

# Install essential build dependencies for OTP
RUN yum install -y \
    ncurses-devel \
    openssl-devel \
    libxslt \
    java-1.8.0-openjdk-devel \
    glibc-locale-source \
    glibc-langpack-en

RUN yum groupinstall "Development Tools" -y

# Generate locale
RUN localedef -i en_US -f UTF-8 en_US.UTF-8

WORKDIR /tmp

RUN cd /tmp && \
        wget --tries=1 --timeout=30 "http://erlang.org/download/otp_src_${OTP_VERSION}.tar.gz" -O otp_src_${OTP_VERSION}.tar.gz || \
        wget "https://github.com/erlang/otp/releases/download/OTP-${OTP_VERSION}/otp_src_${OTP_VERSION}.tar.gz" -O otp_src_${OTP_VERSION}.tar.gz && \
        tar xfz otp_src_${OTP_VERSION}.tar.gz && \
        cd otp_src_${OTP_VERSION} && \
        ./configure \
            --prefix=/usr/local \
            --enable-smp-support \
            --enable-threads \
            --enable-kernel-poll \
            --disable-hipe \
            --without-javac \
            --without-odbc \
            --without-wx \
            --without-debugger \
            --without-observer \
            --without-et \
            --without-termcap && \
        export ERL_TOP=/tmp/otp_src_${OTP_VERSION} && \
        export HOME=/tmp && \
        make && make install && \
        cd /tmp && rm -rf otp_src_${OTP_VERSION} otp_src_${OTP_VERSION}.tar.gz

WORKDIR /tmp

# Install Elixir
RUN set -xe \
	&& ELIXIR_DOWNLOAD_URL="https://github.com/elixir-lang/elixir/archive/v${ELIXIR_VERSION}.tar.gz" \
	&& ELIXIR_DOWNLOAD_SHA256="8e136c0a92160cdad8daa74560e0e9c6810486bd232fbce1709d40fcc426b5e0" \
	&& curl -fSL -o elixir-src.tar.gz $ELIXIR_DOWNLOAD_URL \
	&& echo "$ELIXIR_DOWNLOAD_SHA256  elixir-src.tar.gz" | sha256sum -c - \
	&& mkdir -p /usr/local/src/elixir \
	&& tar -xzC /usr/local/src/elixir --strip-components=1 -f elixir-src.tar.gz \
	&& rm elixir-src.tar.gz \
	&& cd /usr/local/src/elixir \
	&& make install clean \
	&& find /usr/local/src/elixir/ -type f -not -regex "/usr/local/src/elixir/lib/[^\/]*/lib.*" -exec rm -rf {} + \
	&& find /usr/local/src/elixir/ -type d -depth -empty -delete

RUN mix local.hex --force
RUN mix local.rebar --force

# install node
RUN yum install -y gcc-c++ make
RUN yum install https://rpm.nodesource.com/pub_16.x/nodistro/repo/nodesource-release-nodistro-1.noarch.rpm -y
RUN yum install nodejs -y --setopt=nodesource-nodejs.module_hotfixes=1
RUN npm install -g yarn

# Set the working directory inside the container
WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]