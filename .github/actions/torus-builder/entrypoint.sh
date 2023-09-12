#!/bin/sh

set -e
set -x

RELEASE_SHA=$1

mix local.hex --force
mix local.rebar --force
# mix archive.install hex phx_new 1.5.9 --force

mix deps.get --only prod
MIX_ENV=prod SHA=$RELEASE_SHA mix compile

yarn --cwd ./assets
NODE_ENV=production npm run deploy --prefix ./assets
echo $?
NODE_ENV=production npm run deploy-node --prefix ./assets
echo $?

MIX_ENV=prod mix assets.deploy
MIX_ENV=prod SHA=$RELEASE_SHA mix release
