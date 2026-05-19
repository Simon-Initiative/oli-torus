#!/bin/sh

set -eu

HA_PROXY_MODE="${HA_PROXY_MODE:-minio}"
TORUS_BACKEND_HOST="${TORUS_BACKEND_HOST:-host.docker.internal}"
TORUS_BACKEND_PORT="${TORUS_BACKEND_PORT:-${HTTP_PORT:-8080}}"
RENDERED_CONFIG="${RENDERED_CONFIG:-/tmp/haproxy.cfg}"

render_minio() {
  MINIO_API_HOST="${MINIO_API_HOST:-host.docker.internal}"
  MINIO_API_PORT="${MINIO_API_PORT:-${AWS_S3_PORT:-9000}}"
  MINIO_CONSOLE_HOST="${MINIO_CONSOLE_HOST:-$MINIO_API_HOST}"
  MINIO_CONSOLE_PORT="${MINIO_CONSOLE_PORT:-9001}"
  MEDIA_BUCKET="${MEDIA_BUCKET:-${S3_MEDIA_BUCKET_NAME:-torus-media-dev}}"

  sed \
    -e "s/__TORUS_BACKEND_HOST__/${TORUS_BACKEND_HOST}/g" \
    -e "s/__TORUS_BACKEND_PORT__/${TORUS_BACKEND_PORT}/g" \
    -e "s/__MINIO_API_HOST__/${MINIO_API_HOST}/g" \
    -e "s/__MINIO_API_PORT__/${MINIO_API_PORT}/g" \
    -e "s/__MINIO_CONSOLE_HOST__/${MINIO_CONSOLE_HOST}/g" \
    -e "s/__MINIO_CONSOLE_PORT__/${MINIO_CONSOLE_PORT}/g" \
    -e "s/__MEDIA_BUCKET__/${MEDIA_BUCKET}/g" \
    /usr/local/etc/haproxy/haproxy.minio.cfg.template >"$RENDERED_CONFIG"
}

render_origin() {
  : "${MEDIA_ORIGIN_HOST:?MEDIA_ORIGIN_HOST is required when HA_PROXY_MODE=s3}"

  MEDIA_ORIGIN_PORT="${MEDIA_ORIGIN_PORT:-80}"

  sed \
    -e "s/__TORUS_BACKEND_HOST__/${TORUS_BACKEND_HOST}/g" \
    -e "s/__TORUS_BACKEND_PORT__/${TORUS_BACKEND_PORT}/g" \
    -e "s/__MEDIA_ORIGIN_HOST__/${MEDIA_ORIGIN_HOST}/g" \
    -e "s/__MEDIA_ORIGIN_PORT__/${MEDIA_ORIGIN_PORT}/g" \
    /usr/local/etc/haproxy/haproxy.origin.cfg.template >"$RENDERED_CONFIG"
}

case "$HA_PROXY_MODE" in
  minio)
    render_minio
    ;;

  s3 | origin)
    render_origin
    ;;

  *)
    echo "Unsupported HA_PROXY_MODE: $HA_PROXY_MODE" >&2
    echo "Expected one of: minio, s3, origin" >&2
    exit 1
    ;;
esac

exec haproxy -W -db -f "$RENDERED_CONFIG"
