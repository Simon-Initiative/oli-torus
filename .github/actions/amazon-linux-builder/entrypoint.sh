#!/bin/sh

set -e
set -x

RELEASE_SHA=$1

LANG="en_US.utf8"
LANGUAGE="en_US:"
LC_ALL=en_US.UTF-8

mix local.hex --force
mix local.rebar --force
mix archive.install hex mix_gleam 0.6.2 --force
# mix archive.install hex phx_new 1.5.9 --force

MIX_ENV=prod mix deps.get --only prod
yarn --cwd ./assets
NODE_ENV=production npm run deploy --prefix ./assets
NODE_ENV=production npm run deploy-node --prefix ./assets

cd gleam && gleam build --target erlang && cd ..
MIX_ENV=prod SHA=$RELEASE_SHA mix compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod SHA=$RELEASE_SHA mix release
