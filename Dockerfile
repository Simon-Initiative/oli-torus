# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20240722-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.19.2-erlang-28.1.1-debian-bullseye-20251103-slim
#
ARG ELIXIR_VERSION=1.19.2
ARG OTP_VERSION=28.1.1
ARG GLEAM_VERSION=1.16.0
ARG DEBIAN_VERSION=bullseye-20251103-slim
ARG NODE_VERSION=24.20.0

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM node:${NODE_VERSION}-bullseye-slim@sha256:f7818cba7c85740e6f9dd31553636131d01e9992fb7d112b9b0893afd884d1d6 AS node

FROM ${BUILDER_IMAGE} AS builder

ARG GLEAM_VERSION
ARG SHA
ENV SHA=${SHA}

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    ca-certificates curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Use the same pinned Node.js distribution for asset compilation and at runtime.
COPY --from=node /usr/local/ /usr/local/
COPY --from=node /opt/yarn-v1.22.22/ /opt/yarn-v1.22.22/

# install Gleam for the mix_gleam compiler
RUN curl -fsSL -o /tmp/gleam.tar.gz "https://github.com/gleam-lang/gleam/releases/download/v${GLEAM_VERSION}/gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz" && \
    tar -xzf /tmp/gleam.tar.gz -C /usr/local/bin gleam && \
    rm /tmp/gleam.tar.gz

# prepare build dir
WORKDIR /app

# When cross-building (e.g., linux/amd64 target on Apple Silicon), Erlang/OTP 28's
# dual-mapped JIT crashes under QEMU emulation. Disable the dual-mapped scheduler
# during the build to keep mix and other BEAM tooling stable.
ENV ERL_FLAGS="+JMsingle true"

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix archive.install hex mix_gleam 0.6.2 --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
COPY gleam/gleam.toml gleam/manifest.toml ./gleam/
RUN mix deps.get --only $MIX_ENV
RUN cd gleam && gleam deps download
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY gleam gleam
RUN cd gleam && gleam clean && gleam deps download && gleam build --target erlang --warnings-as-errors

COPY assets assets

# install node dependencies
RUN yarn --cwd ./assets --frozen-lockfile

# compile assets
RUN NODE_ENV=production npm run deploy --prefix ./assets
RUN NODE_ENV=production npm run deploy-node --prefix ./assets

RUN mix assets.deploy

# Compile the release
RUN mix compile --force

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel

# Build the release
RUN mix release
RUN DATABASE_URL=ecto://postgres:postgres@localhost/oli \
    SECRET_KEY_BASE=0000000000000000000000000000000000000000000000000000000000000000 \
    LIVE_VIEW_SALT=00000000000000000000000000000000 \
    HOST=localhost \
    S3_MEDIA_BUCKET_NAME=torus-media \
    S3_XAPI_BUCKET_NAME=torus-xapi \
    MEDIA_URL=http://localhost/torus-media \
    CLOAK_VAULT_KEY=HXCdm5z61eNgUpnXObJRv94k3JnKSrnfwppyb60nz6w= \
    RELEASE_DISTRIBUTION=none \
    _build/prod/rel/oli/bin/oli eval 'path = :code.which(:torus_math); unless is_list(path) and not String.contains?(List.to_string(path), "gleam/build"), do: raise("torus_math loaded from unexpected path: #{inspect(path)}"); case Oli.Math.Gleam.parse("x + 1") do {:ok, _parsed} -> :ok; other -> raise("Gleam math release smoke failed: #{inspect(other)}") end'

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

COPY --from=node /usr/local/bin/node /usr/local/bin/node

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install goose for database migrations
RUN curl -fsSL https://raw.githubusercontent.com/pressly/goose/master/install.sh | sh

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/oli ./

USER nobody

CMD ["/app/bin/server"]
