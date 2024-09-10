
ARG ELIXIR_VERSION=1.17.2
ARG OTP_VERSION=27.0.1
ARG DEBIAN_VERSION=bullseye-20240722-slim

ARG IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"

FROM ${IMAGE} as dev

RUN apt-get update -qq && \
  apt-get install -qq -y \
  curl \
  git \
  dirmngr \
  gpg \
  gawk \
  unzip \
  build-essential \
  autoconf \
  libssl-dev \
  libncurses5-dev \
  m4 \
  libssh-dev \
  inotify-tools

RUN useradd -ms $(which bash) asdf

USER asdf

RUN git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v0.8.1 && \
  echo '. $HOME/.asdf/asdf.sh' >> $HOME/.bashrc && \
  echo '. $HOME/.asdf/asdf.sh' >> $HOME/.profile

ENV PATH /home/asdf/.asdf/bin:/home/asdf/.asdf/shims:$PATH

RUN /bin/bash -c "\
  asdf plugin-add nodejs && \
  asdf plugin-add yarn \
  "

WORKDIR /workspace

COPY .tool-versions /workspace

RUN /bin/bash -c "ls -la && asdf install"

RUN /bin/bash -c "yarn"
RUN /bin/bash -c "mix local.hex --force"
RUN /bin/bash -c "mix local.rebar --force"

ENV LANG C.UTF-8
