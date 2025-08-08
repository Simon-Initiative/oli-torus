#!/bin/bash

export PATH="/root/.asdf/bin:/root/.asdf/shims:$PATH"
export ASDF_DIR="/root/.asdf"
export ASDF_DATA_DIR="/root/.asdf"

# Ensure ASDF shims are refreshed for the Go-based version
asdf reshim

# Debug: Check if node is available
echo "Checking for node..."
which node || echo "node not found in PATH"
echo "PATH: $PATH"
ls -la /root/.asdf/shims/ | grep node || echo "No node shims found"

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
cd ./assets && NODE_ENV=production node --max-old-space-size=8192 node_modules/webpack/bin/webpack.js --mode production
cd ./assets && NODE_ENV=production npx webpack --mode production --config webpack.config.node.js
cd ..

MIX_ENV=prod mix assets.deploy
MIX_ENV=prod SHA=$RELEASE_SHA mix release
