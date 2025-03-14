FROM amazonlinux:2

RUN yum update -y
RUN yum install -y tar wget git

RUN yum install ncurses-devel openssl11-devel -y
RUN yum groupinstall "Development Tools" -y

WORKDIR /tmp
RUN RUN wget --tries=1 --timeout=30 "http://erlang.org/download/otp_src_26.1.tar.gz" -O otp_src_26.1.tar.gz || wget "https://github.com/erlang/otp/releases/download/OTP-26.1/otp_src_26.1.tar.gz" -O otp_src_26.1.tar.gz
RUN tar xfz otp_src_26.1.tar.gz
WORKDIR /tmp/otp_src_26.1/
RUN ./configure
RUN make && make install

WORKDIR /tmp
RUN wget "https://github.com/elixir-lang/elixir/archive/v1.17.2.tar.gz"
RUN tar xfz v1.17.2.tar.gz
WORKDIR /tmp/elixir-1.17.2/
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
