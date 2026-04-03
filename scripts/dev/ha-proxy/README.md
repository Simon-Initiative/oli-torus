# HAProxy Dev Setup

This directory contains the local-development HAProxy setup used to front Torus over HTTPS.

There is a single Docker image, a single Compose file, and one runtime mode switch:

- `HA_PROXY_MODE=minio` routes media traffic to local MinIO
- `HA_PROXY_MODE=s3` routes media traffic to an external media origin such as CloudFront

The shared Compose file is:

- [`docker-compose-haproxy.yml`](/Users/raph/staff/all_sources/oli/docker-compose-haproxy.yml)

## 1. Prerequisites

Make sure `oli.env` contains:

```bash
ENABLE_HTTPS=false
```

HAProxy is intended to own ports `80` and `443`. If Phoenix HTTPS is enabled, Torus will also try to bind `443` and conflict with the proxy.

You also need:

- `mkcert` installed and available on `PATH`
- permission to install/use the local `mkcert` CA in your OS trust store
- write access to `scripts/dev/ha-proxy/`

Install `mkcert`:

macOS:

```bash
brew install mkcert nss
```

Ubuntu or Debian:

```bash
sudo apt update
sudo apt install libnss3-tools

curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
chmod +x mkcert-v*-linux-amd64
sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
```

Linux with Homebrew:

```bash
brew install mkcert nss
```

## 2. Generate The Local HTTPS Certificate

Generate the HAProxy PEM:

```bash
./scripts/dev/generate_haproxy_localhost_cert.sh
```

This writes:

```bash
scripts/dev/ha-proxy/combined.pem
```

To add extra SAN hostnames:

```bash
./scripts/dev/generate_haproxy_localhost_cert.sh torus.localdev.me host.docker.internal
```

For inline help:

```bash
./scripts/dev/generate_haproxy_localhost_cert.sh --help
```

The script runs `mkcert -install` as needed to create or trust the local development CA.

## 3. Configure `oli.env`

The shared Compose file loads `oli.env` into HAProxy. Set these values there.

Always set:

```bash
ENABLE_HTTPS=false
HA_PROXY_MODE=minio
```

or

```bash
ENABLE_HTTPS=false
HA_PROXY_MODE=s3
```

### When `HA_PROXY_MODE=minio`

Recommended values:

```bash
HA_PROXY_MODE=minio
HTTP_PORT=8080
AWS_S3_PORT=9000
S3_MEDIA_BUCKET_NAME=torus-media-dev
```

### When `HA_PROXY_MODE=s3`

Required values:

```bash
HA_PROXY_MODE=s3
MEDIA_ORIGIN_HOST=media-origin.example.com
MEDIA_ORIGIN_PORT=80
TORUS_BACKEND_HOST=host.docker.internal
HTTP_PORT=8080
```

Notes:

- `TORUS_BACKEND_PORT` is optional and defaults to `HTTP_PORT`
- `docker-compose-haproxy.yml` still includes MinIO and ClickHouse for local parity, but in `s3` mode HAProxy routes media to `MEDIA_ORIGIN_HOST`, not to local MinIO

## 4. Build The HAProxy Image

The single image is built from:

- `scripts/dev/ha-proxy/Dockerfile`

Build it with:

```bash
docker compose -f docker-compose-haproxy.yml build haproxy
```

## 5. Start The Stack

Start everything with:

```bash
docker compose -f docker-compose-haproxy.yml up -d
```

This Compose file includes:

- `postgres`
- `minio`
- `clickhouse`
- `haproxy`

If you changed MinIO-related config and want a clean container refresh:

```bash
docker compose -f docker-compose-haproxy.yml up -d --force-recreate minio
```

## 6. Create Local MinIO Buckets When Using MinIO Mode

If `HA_PROXY_MODE=minio`, create the expected local buckets:

```bash
./scripts/dev/setup_minio_buckets.sh
```

That helper defaults to:

- `docker-compose-haproxy.yml`
- service name `minio`

## 7. Run Without Compose

If you want to run the same image without Compose:

```bash
docker build -f scripts/dev/ha-proxy/Dockerfile -t oli-haproxy scripts/dev/ha-proxy
docker run --rm \
  --add-host=host.docker.internal:host-gateway \
  --env-file oli.env \
  -p 80:80 \
  -p 443:443 \
  oli-haproxy
```

## 8. Reference

Templates:

- `haproxy_minio_docker.cfg`
  - Template for local Torus + local MinIO
  - Proxies Torus to `host.docker.internal:${HTTP_PORT}` in practice
  - Proxies MinIO API and Console to the configured local MinIO endpoints
  - Rewrites `/super_media/...` and `/superactivity/...` to the local media bucket layout

- `haproxy_docker.cfg`
  - Template for local Torus + external media-origin routing
  - Rendered at container start
  - Proxies Torus to `host.docker.internal:${HTTP_PORT}` by default
  - Requires `MEDIA_ORIGIN_HOST` in `s3` mode

Runtime entrypoint:

- `docker-entrypoint.sh`
  - Selects the template based on `HA_PROXY_MODE`
  - Renders the final HAProxy config to `/tmp/haproxy.cfg`
  - Starts HAProxy with the rendered config

Docker image:

- `Dockerfile`
  - Single HAProxy image for both `minio` and `s3` modes
  - Copies `combined.pem` to `/certs/combined.pem`
  - Copies both config templates and the shared entrypoint

Generated certificate:

- `combined.pem`
  - PEM file used by HAProxy for HTTPS on port `443`
  - Contains both the private key and certificate

General notes:

- Both modes expect Phoenix to be reachable on `host.docker.internal`
- On Linux, `host.docker.internal` may require `--add-host=host.docker.internal:host-gateway` or the equivalent Compose `extra_hosts` entry
