FROM amazonlinux:2

ARG ELIXIR_VERSION=1.19.2
ARG OTP_VERSION=28.1.1
ARG GLEAM_VERSION=1.16.0
ARG NODE_VERSION=24.20.0
ARG NODE_LINUX_X64_GLIBC_217_SHA256=6a0c8e38dc77fa537aac992ecd7560d309ec81a73b4822b410553217ad52c064

RUN yum update -y
RUN yum install -y tar wget git xz

RUN yum install ncurses-devel openssl11-devel -y
RUN yum groupinstall "Development Tools" -y

WORKDIR /tmp
RUN wget --tries=1 --timeout=30 "http://erlang.org/download/otp_src_${OTP_VERSION}.tar.gz" -O otp_src_${OTP_VERSION}.tar.gz || wget "https://github.com/erlang/otp/releases/download/OTP-${OTP_VERSION}/otp_src_${OTP_VERSION}.tar.gz" -O otp_src_${OTP_VERSION}.tar.gz
RUN tar xfz otp_src_${OTP_VERSION}.tar.gz
WORKDIR /tmp/otp_src_${OTP_VERSION}/
RUN ./configure --disable-jit
RUN make && make install

WORKDIR /tmp
RUN wget "https://github.com/elixir-lang/elixir/archive/v${ELIXIR_VERSION}.tar.gz"
RUN tar xfz v${ELIXIR_VERSION}.tar.gz
WORKDIR /tmp/elixir-${ELIXIR_VERSION}/
ENV PATH="${PATH}:/usr/local/bin"
RUN make && make install

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix archive.install hex mix_gleam 0.6.2 --force

WORKDIR /tmp
RUN wget "https://github.com/gleam-lang/gleam/releases/download/v${GLEAM_VERSION}/gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz"
RUN tar xfz gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz
RUN mv gleam /usr/local/bin/gleam

# The official Node.js Linux binaries require glibc 2.28, while Amazon Linux 2
# provides glibc 2.26. Use Node's glibc 2.17-compatible community build so this
# builder continues to match the production server platform.
WORKDIR /tmp
RUN wget "https://unofficial-builds.nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64-glibc-217.tar.xz" \
    && echo "${NODE_LINUX_X64_GLIBC_217_SHA256}  node-v${NODE_VERSION}-linux-x64-glibc-217.tar.xz" | sha256sum --check --strict \
    && tar -xJf "node-v${NODE_VERSION}-linux-x64-glibc-217.tar.xz" -C /usr/local --strip-components=1 \
    && rm "node-v${NODE_VERSION}-linux-x64-glibc-217.tar.xz"
RUN npm install -g yarn@1.22.22

WORKDIR /app

# fix elixir encoding warning
# https://stackoverflow.com/questions/32407164/the-vm-is-running-with-native-name-encoding-of-latin1-which-may-cause-elixir-to
ENV LANG="en_US.utf8"
ENV LANGUAGE="en_US:"
ENV LC_ALL=en_US.UTF-8

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
