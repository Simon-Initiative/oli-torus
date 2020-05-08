#!/bin/sh -l

mix deps.get --only prod
mix compile

npm install --prefix ./assets
npm run deploy --prefix ./assets
mix phx.digest

mix release
