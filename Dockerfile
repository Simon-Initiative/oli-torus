FROM elixir:1.10-alpine

WORKDIR /usr/src/app

# Install system dependencies
## General
RUN apk add --update inotify-tools curl git npm bash

## Hex
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix archive.install hex phx_new 1.4.13

## NodeJS
RUN npm install -g n && n 12

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
CMD [ "mix", "phx.server" ]