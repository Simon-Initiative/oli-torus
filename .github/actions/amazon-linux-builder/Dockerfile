# Use Amazon Linux 2023 as the base image
FROM amazonlinux:2023

ARG ERLANG_VERSION=28.0.2
ARG ELIXIR_VERSION=1.18.4-otp-28
ARG NODE_VERSION=16.14.2

# Install system dependencies with --allowerasing to handle conflicts
RUN yum update -y && \
    yum install -y \
    git \
    curl \
    tar \
    gzip \
    zip \
    gcc \
    gcc-c++ \
    make \
    autoconf \
    openssl \
    openssl-devel \
    ncurses-devel \
    wget \
    gnupg \
    nano \
    glibc-langpack-en --allowerasing

# Install ASDF
RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.18.0 && \
    echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc && \
    echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc

# Install Erlang plugin and latest version
RUN source ~/.asdf/asdf.sh && \
    asdf plugin-add erlang https://github.com/asdf-vm/asdf-erlang.git && \
    asdf install erlang ${ERLANG_VERSION} && \
    asdf global erlang ${ERLANG_VERSION}

# Install Elixir plugin and latest version
RUN source ~/.asdf/asdf.sh && \
    asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git && \
    asdf install elixir ${ELIXIR_VERSION} && \
    asdf global elixir ${ELIXIR_VERSION}

# Install Node plugin and latest version
RUN source ~/.asdf/asdf.sh && \
    asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git && \
    asdf install nodejs ${NODE_VERSION} && \
    asdf global nodejs ${NODE_VERSION}

# Set the working directory inside the container
WORKDIR /app

# fix elixir encoding warning
# https://stackoverflow.com/questions/32407164/the-vm-is-running-with-native-name-encoding-of-latin1-which-may-cause-elixir-to
ENV LANG="en_US.utf8"
ENV LANGUAGE="en_US:"
ENV LC_ALL=en_US.UTF-8

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]