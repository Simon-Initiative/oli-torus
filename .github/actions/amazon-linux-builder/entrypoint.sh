#!/bin/sh

set -e
set -x

RELEASE_SHA=$1

LANG="en_US.utf8"
LANGUAGE="en_US:"
LC_ALL=en_US.UTF-8

mix local.hex --force
mix local.rebar --force

mix deps.get --only prod
MIX_ENV=prod SHA=$RELEASE_SHA mix compile

yarn --cwd ./assets
NODE_ENV=production npm run deploy --prefix ./assets
NODE_ENV=production npm run deploy-node --prefix ./assets

MIX_ENV=prod mix assets.deploy
MIX_ENV=prod SHA=$RELEASE_SHA mix release --overwrite
