#!/bin/sh

mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new 1.5.1

mix deps.get --only prod
MIX_ENV=prod mix compile

npm install --prefix ./assets
npm run deploy --prefix ./assets
mix phx.digest

MIX_ENV=prod mix release
