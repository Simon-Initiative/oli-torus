#!/usr/bin/env bash

# Generates a localhost-focused PEM file for the HAProxy dev containers.
#
# Requirements:
# - mkcert must be installed and available on PATH
# - the local mkcert CA must be installable in the current OS trust store
# - write access to scripts/dev/ha-proxy/
#
# Usage:
#   ./scripts/dev/generate_haproxy_localhost_cert.sh
#   ./scripts/dev/generate_haproxy_localhost_cert.sh torus.localdev.me host.docker.internal
#   ./scripts/dev/generate_haproxy_localhost_cert.sh --help
#
# Output:
# - writes scripts/dev/ha-proxy/combined.pem
# - combines the generated private key and certificate for HAProxy
#
# Notes:
# - always includes localhost, 127.0.0.1, and ::1
# - any extra arguments are added as SAN hostnames/IPs

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/scripts/dev/ha-proxy"
OUTPUT_FILE="$OUTPUT_DIR/combined.pem"

usage() {
  cat <<'EOF'
Generate a trusted localhost certificate PEM for the HAProxy dev containers.

Usage:
  ./scripts/dev/generate_haproxy_localhost_cert.sh [extra-hostname-or-ip ...]
  ./scripts/dev/generate_haproxy_localhost_cert.sh --help

Requirements:
  - mkcert installed and available on PATH
  - permission to install/use the local mkcert CA in your OS trust store
  - write access to scripts/dev/ha-proxy/

Behavior:
  - always includes SAN entries for localhost, 127.0.0.1, and ::1
  - appends any extra arguments as additional SAN hostnames/IPs
  - writes scripts/dev/ha-proxy/combined.pem

Examples:
  ./scripts/dev/generate_haproxy_localhost_cert.sh
  ./scripts/dev/generate_haproxy_localhost_cert.sh torus.localdev.me host.docker.internal
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if ! command -v mkcert >/dev/null 2>&1; then
  echo "mkcert is required."
  echo "Install it first, for example:"
  echo "  brew install mkcert nss"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CERT_FILE="$TMP_DIR/localhost-cert.pem"
KEY_FILE="$TMP_DIR/localhost-key.pem"

SAN_NAMES=("localhost" "127.0.0.1" "::1")
if [[ $# -gt 0 ]]; then
  SAN_NAMES+=("$@")
fi

echo "Installing local mkcert CA if needed..."
mkcert -install

echo "Generating localhost certificate for: ${SAN_NAMES[*]}"
mkcert -cert-file "$CERT_FILE" -key-file "$KEY_FILE" "${SAN_NAMES[@]}"

cat "$KEY_FILE" "$CERT_FILE" >"$OUTPUT_FILE"

echo "Wrote HAProxy PEM to:"
echo "  $OUTPUT_FILE"
echo
echo "You can now rebuild the HAProxy image:"
echo "  docker compose -f docker-compose-dev-minio.yml build haproxy"
echo "  docker compose -f docker-compose-dev-minio.yml up -d haproxy"
