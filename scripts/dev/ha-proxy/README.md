# HAProxy Dev Setup

This directory contains the local-development HAProxy configs and Dockerfiles used to front Torus over HTTPS.

There are two supported modes:

- MinIO-backed local media routing
- regular external media-origin routing

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

## 3. Choose A Proxy Mode

### Option A: MinIO-Backed Local Media Routing

Use this when you want `/super_media/...` and `/superactivity/...` routed to local MinIO.

Files used:

- `scripts/dev/ha-proxy/Dockerfile.minio`
- `scripts/dev/ha-proxy/haproxy_minio_docker.cfg`
- `docker-compose-dev-minio.yml`

Build the services:

```bash
docker compose -f docker-compose-dev-minio.yml build haproxy
```

Start the local services:

```bash
docker compose -f docker-compose-dev-minio.yml up -d
```

If you changed MinIO-related config and want a clean container refresh:

```bash
docker compose -f docker-compose-dev-minio.yml up -d --force-recreate minio
```

Create the expected local buckets:

```bash
./scripts/dev/setup_minio_buckets.sh
```

### Option B: Regular External Media-Origin Routing

Use this when you want HAProxy to send media traffic to an external origin such as CloudFront.

Files used:

- `scripts/dev/ha-proxy/Dockerfile.docker`
- `scripts/dev/ha-proxy/haproxy_docker.cfg`
- `docker-compose-dev-s3.yml`

Required values in `oli.env`:

- `MEDIA_ORIGIN_HOST`
- `MEDIA_ORIGIN_PORT`
- `TORUS_BACKEND_HOST`
- `HTTP_PORT`

Build the services:

```bash
docker compose -f docker-compose-dev-s3.yml build haproxy
```

Start the local services:

```bash
docker compose -f docker-compose-dev-s3.yml up -d
```

Notes for this mode:

- `docker-compose-dev-s3.yml` loads `./oli.env` into the HAProxy container.
- HAProxy derives the Torus backend port from `HTTP_PORT` by default.
- `TORUS_BACKEND_PORT` is available as an override if you run the image directly instead of compose.
- `docker-compose-dev-s3.yml` includes MinIO for local parity, but this HAProxy mode routes media to `MEDIA_ORIGIN_HOST`, not to that MinIO instance.

If you want to run the regular Docker-safe variant without Compose:

```bash
docker build -f scripts/dev/ha-proxy/Dockerfile.docker -t oli-haproxy-docker scripts/dev/ha-proxy
docker run --rm \
  --add-host=host.docker.internal:host-gateway \
  --env-file oli.env \
  -p 80:80 \
  -p 443:443 \
  oli-haproxy-docker
```

## 4. Reference

Config files:

- `haproxy_minio_docker.cfg`
  - Docker-safe HAProxy config for local Torus + local MinIO.
  - Proxies Torus to `host.docker.internal:${HTTP_PORT}` in practice.
  - Proxies MinIO API to `host.docker.internal:9000`.
  - Proxies MinIO Console to `host.docker.internal:9001`.
  - Rewrites `/super_media/...` and `/superactivity/...` to the local MinIO bucket layout.

- `haproxy_docker.cfg`
  - Docker-safe HAProxy config for local Torus + the regular external media/CDN flow.
  - Rendered as a template by environment at container start.
  - Proxies Torus to `host.docker.internal:${HTTP_PORT}` by default.
  - Requires the media origin host to be provided explicitly.

Dockerfiles:

- `Dockerfile.minio`
  - Builds the MinIO-backed variant.
  - Copies `combined.pem` to `/certs/combined.pem`.
  - Bakes in `haproxy_minio_docker.cfg`.

- `Dockerfile.docker`
  - Builds the regular Docker-safe variant.
  - Copies `combined.pem` to `/certs/combined.pem`.
  - Renders `haproxy_docker.cfg` from environment at container start.

Generated certificate:

- `combined.pem`
  - PEM file used by HAProxy for HTTPS on port `443`.
  - Contains both the private key and certificate.

General notes:

- Both Docker variants expect Phoenix to be reachable on `host.docker.internal`.
- On Linux, `host.docker.internal` may require `--add-host=host.docker.internal:host-gateway` or the equivalent Compose `extra_hosts` entry.
