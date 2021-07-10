FROM elixir:latest

# use bash as shell
SHELL ["/bin/bash", "-c"]

# install node.js
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
RUN apt-get update
RUN apt-get install nodejs --yes

# copy project files
COPY . .

# install elixir dependencies
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get

# install node modules
RUN cd assets && npm install --legacy-peer-deps && cd ..
