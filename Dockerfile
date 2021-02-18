FROM elixir:1.11-slim

WORKDIR /usr/src/app

# Install system dependencies
## General
RUN apt-get update -y
RUN apt-get install -y inotify-tools curl git npm bash supervisor
RUN mkdir -p /var/log/supervisor

## Hex
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix archive.install hex phx_new 1.5.7

## NodeJS
RUN npm install -g n && n 12

## localtunnel
RUN npm install -g localtunnel

# Copy all app files to image, excluding those in .dockerignore
COPY . .

# Install application dependencies
RUN mix deps.get
RUN cd assets && npm install

# Declare image volumes
VOLUME ["/usr/src/app/deps"]
VOLUME ["/usr/src/app/build"]
VOLUME ["/usr/src/app/assets/node_modules"]

# Run Phoenix server on container start
COPY ./supervisord.conf /etc/supervisord.conf
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf", "-n"]
