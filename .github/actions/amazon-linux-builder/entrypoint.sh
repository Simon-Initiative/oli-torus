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

cd gleam
gleam clean
gleam deps download
gleam build --target erlang --warnings-as-errors
cd ..

MIX_ENV=prod SHA=$RELEASE_SHA mix compile --force
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod SHA=$RELEASE_SHA mix release

DATABASE_URL=${DATABASE_URL:-ecto://postgres:postgres@localhost/oli} \
SECRET_KEY_BASE=${SECRET_KEY_BASE:-0000000000000000000000000000000000000000000000000000000000000000} \
LIVE_VIEW_SALT=${LIVE_VIEW_SALT:-00000000000000000000000000000000} \
HOST=${HOST:-localhost} \
S3_MEDIA_BUCKET_NAME=${S3_MEDIA_BUCKET_NAME:-torus-media} \
S3_XAPI_BUCKET_NAME=${S3_XAPI_BUCKET_NAME:-torus-xapi} \
MEDIA_URL=${MEDIA_URL:-http://localhost/torus-media} \
CLOAK_VAULT_KEY=${CLOAK_VAULT_KEY:-HXCdm5z61eNgUpnXObJRv94k3JnKSrnfwppyb60nz6w=} \
RELEASE_DISTRIBUTION=none \
_build/prod/rel/oli/bin/oli eval 'path = :code.which(:torus_math); unless is_list(path) and not String.contains?(List.to_string(path), "gleam/build"), do: raise("torus_math loaded from unexpected path: #{inspect(path)}"); case Oli.Math.Gleam.parse("x + 1") do {:ok, _parsed} -> :ok; other -> raise("Gleam math release smoke failed: #{inspect(other)}") end'
