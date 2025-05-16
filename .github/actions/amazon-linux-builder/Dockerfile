FROM amazonlinux:2

ARG ELIXIR_VERSION=1.17.2
ARG OTP_VERSION=26.1

RUN yum update -y
RUN yum install -y tar wget git

RUN yum install ncurses-devel openssl11-devel -y
RUN yum groupinstall "Development Tools" -y

WORKDIR /tmp
RUN wget --tries=1 --timeout=30 "http://erlang.org/download/otp_src_${OTP_VERSION}.tar.gz" -O otp_src_${OTP_VERSION}.tar.gz || wget "https://github.com/erlang/otp/releases/download/OTP-${OTP_VERSION}/otp_src_${OTP_VERSION}.tar.gz" -O otp_src_${OTP_VERSION}.tar.gz
RUN tar xfz otp_src_${OTP_VERSION}.tar.gz
WORKDIR /tmp/otp_src_${OTP_VERSION}/
RUN ./configure
RUN make && make install

WORKDIR /tmp
RUN wget "https://github.com/elixir-lang/elixir/archive/v${ELIXIR_VERSION}.tar.gz"
RUN tar xfz v${ELIXIR_VERSION}.tar.gz
WORKDIR /tmp/elixir-${ELIXIR_VERSION}/
ENV PATH="${PATH}:/usr/local/bin"
RUN make && make install

RUN mix local.hex --force
RUN mix local.rebar --force

# install node
RUN yum install -y gcc-c++ make
RUN yum install https://rpm.nodesource.com/pub_16.x/nodistro/repo/nodesource-release-nodistro-1.noarch.rpm -y
RUN yum install nodejs -y --setopt=nodesource-nodejs.module_hotfixes=1
RUN npm install -g yarn

WORKDIR /app

# fix elixir encoding warning
# https://stackoverflow.com/questions/32407164/the-vm-is-running-with-native-name-encoding-of-latin1-which-may-cause-elixir-to
ENV LANG="en_US.utf8"
ENV LANGUAGE="en_US:"
ENV LC_ALL=en_US.UTF-8

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
