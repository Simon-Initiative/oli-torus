# FROM elixir:1.10
FROM elixir:1.10-alpine

WORKDIR /usr/src/app

# Install system dependencies
## Hex
RUN mix local.hex --force
RUN mix archive.install hex phx_new 1.4.13

# ## NodeJS
# RUN apt-get -y update
# RUN apt-get -y install npm
# RUN npm install -g n && n 12
RUN apk add --update npm bash
RUN npm install -g n && n 12


# Copy all app files to image, excluding those in .dockerignore
COPY . .

RUN mix deps.get
RUN cd assets && npm install

CMD [ "mix", "phx.server" ]