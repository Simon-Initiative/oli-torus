#!/bin/sh

RELEASE_SHA=$1

mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new 1.5.9

mix deps.get --only prod
MIX_ENV=prod SHA=$RELEASE_SHA mix compile

yarn --cwd ./assets
NODE_ENV=production npm run deploy --prefix ./assets
NODE_ENV=production npm run deploy-node --prefix ./assets

MIX_ENV=prod mix assets.deploy
MIX_ENV=prod SHA=$RELEASE_SHA mix release
