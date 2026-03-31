#!/bin/sh

set -eu

: "${MEDIA_ORIGIN_HOST:?MEDIA_ORIGIN_HOST is required}"

TORUS_BACKEND_HOST="${TORUS_BACKEND_HOST:-host.docker.internal}"
TORUS_BACKEND_PORT="${TORUS_BACKEND_PORT:-${HTTP_PORT:-8080}}"
MEDIA_ORIGIN_PORT="${MEDIA_ORIGIN_PORT:-80}"
RENDERED_CONFIG="${RENDERED_CONFIG:-/tmp/haproxy.cfg}"

sed \
  -e "s/__TORUS_BACKEND_HOST__/${TORUS_BACKEND_HOST}/g" \
  -e "s/__TORUS_BACKEND_PORT__/${TORUS_BACKEND_PORT}/g" \
  -e "s/__MEDIA_ORIGIN_HOST__/${MEDIA_ORIGIN_HOST}/g" \
  -e "s/__MEDIA_ORIGIN_PORT__/${MEDIA_ORIGIN_PORT}/g" \
  /usr/local/etc/haproxy/haproxy.cfg.template >"$RENDERED_CONFIG"

exec haproxy -W -db -f "$RENDERED_CONFIG"
