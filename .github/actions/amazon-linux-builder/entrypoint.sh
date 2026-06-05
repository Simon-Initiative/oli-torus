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
DATABASE_URL=ecto://postgres:postgres@localhost/oli \
  SECRET_KEY_BASE=0000000000000000000000000000000000000000000000000000000000000000 \
  LIVE_VIEW_SALT=00000000000000000000000000000000 \
  HOST=localhost \
  S3_MEDIA_BUCKET_NAME=torus-media \
  S3_XAPI_BUCKET_NAME=torus-xapi \
  MEDIA_URL=http://localhost/torus-media \
  CLOAK_VAULT_KEY=HXCdm5z61eNgUpnXObJRv94k3JnKSrnfwppyb60nz6w= \
  _build/prod/rel/oli/bin/oli eval 'case Oli.Math.Gleam.call(:torus_math, :decode_match_config, ["{\"version\":1,\"type\":\"always\"}"]) do {:ok, _} -> IO.puts("server Gleam smoke test passed"); other -> raise "server Gleam smoke test failed: #{inspect(other)}" end'
