#!/usr/bin/env bash

# Sets up local development MinIO buckets using credentials from oli.env.
#
# Usage:
#   scripts/dev/setup_minio_buckets.sh
#
# Requirements:
# - oli.env must exist in the repository root
# - docker compose MinIO service must already be running
# - oli.env should define AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
#
# Optional environment overrides:
# - COMPOSE_FILE: compose file to use instead of docker-compose-dev.yml
# - MINIO_SERVICE: compose service name, defaults to "minio"
# - MINIO_ENDPOINT: MinIO API endpoint, defaults to http://localhost:${AWS_S3_PORT:-9000}
# - S3_MEDIA_BUCKET_NAME: media bucket name, defaults to torus-media-dev
# - S3_XAPI_BUCKET_NAME: xAPI bucket name, defaults to torus-xapi-dev
# - BLOB_STORAGE_BUCKET_NAME: blob bucket name, defaults to torus-blob-dev

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f "$ROOT_DIR/oli.env" ]; then
  echo "Missing oli.env in $ROOT_DIR" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source "$ROOT_DIR/oli.env"
set +a

MINIO_ACCESS_KEY="${AWS_ACCESS_KEY_ID:-}"
MINIO_SECRET_KEY="${AWS_SECRET_ACCESS_KEY:-}"
MINIO_PORT="${AWS_S3_PORT:-9000}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost:${MINIO_PORT}}"
MINIO_SERVICE="${MINIO_SERVICE:-minio}"
MEDIA_BUCKET="${S3_MEDIA_BUCKET_NAME:-torus-media-dev}"
XAPI_BUCKET="${S3_XAPI_BUCKET_NAME:-torus-xapi-dev}"
BLOB_BUCKET="${BLOB_STORAGE_BUCKET_NAME:-torus-blob-dev}"

if [ -z "$MINIO_ACCESS_KEY" ] || [ -z "$MINIO_SECRET_KEY" ]; then
  echo "Missing AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY in oli.env" >&2
  exit 1
fi

compose_args=()
if [ -z "${COMPOSE_FILE:-}" ] && [ -f "$ROOT_DIR/docker-compose-dev.yml" ]; then
  compose_args=(-f docker-compose-dev.yml)
fi

echo "## Setting up MinIO buckets..."
docker compose "${compose_args[@]}" exec -T \
  -e MINIO_ENDPOINT="$MINIO_ENDPOINT" \
  -e MINIO_ACCESS_KEY="$MINIO_ACCESS_KEY" \
  -e MINIO_SECRET_KEY="$MINIO_SECRET_KEY" \
  -e MEDIA_BUCKET="$MEDIA_BUCKET" \
  -e XAPI_BUCKET="$XAPI_BUCKET" \
  -e BLOB_BUCKET="$BLOB_BUCKET" \
  "$MINIO_SERVICE" /bin/sh -c '
    set -eu

    until mc alias set localminio "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"; do
      echo "Waiting for MinIO..."
      sleep 3
    done

    mc mb --ignore-existing "localminio/$MEDIA_BUCKET"
    mc mb --ignore-existing "localminio/$XAPI_BUCKET"
    mc mb --ignore-existing "localminio/$BLOB_BUCKET"

    echo "## Setting MinIO bucket policies..."
    mc anonymous set public "localminio/$MEDIA_BUCKET"
    mc anonymous set public "localminio/$XAPI_BUCKET"
    mc anonymous set public "localminio/$BLOB_BUCKET"
  '
