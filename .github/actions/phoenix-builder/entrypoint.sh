#!/bin/sh

RELEASE_SHA=$1

mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new 1.5.9

mix deps.get --only prod
MIX_ENV=prod SHA=$RELEASE_SHA mix compile

yarn --cwd ./assets
npm run deploy --prefix ./assets
npm run deploy-node --prefix ./assets
mix phx.digest

MIX_ENV=prod SHA=$RELEASE_SHA mix release
