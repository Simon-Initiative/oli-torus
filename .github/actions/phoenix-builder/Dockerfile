FROM amazonlinux:2

RUN yum update -y
RUN yum install -y tar wget git

RUN yum install ncurses-devel openssl-devel -y
RUN yum groupinstall "Development Tools" -y

WORKDIR /tmp
RUN wget "http://erlang.org/download/otp_src_24.0.tar.gz" -O otp24.tar.gz
RUN tar xfz otp24.tar.gz
WORKDIR /tmp/otp_src_24.0/
RUN ./configure
RUN make && make install

WORKDIR /tmp
RUN wget "https://github.com/elixir-lang/elixir/archive/v1.12.0.tar.gz"
RUN tar xfz v1.12.0.tar.gz
WORKDIR /tmp/elixir-1.12.0/
ENV PATH="${PATH}:/usr/local/bin"
RUN make && make install

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix archive.install hex phx_new 1.5.9

# install node
RUN yum install -y gcc-c++ make
RUN curl -sL https://rpm.nodesource.com/setup_15.x | bash -
RUN yum install -y nodejs
RUN npm install -g yarn

# fix elixir encoding warning
# https://stackoverflow.com/questions/32407164/the-vm-is-running-with-native-name-encoding-of-latin1-which-may-cause-elixir-to
ENV LANG=C.UTF-8

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]