# OLI Embedded and Superactivity

This guide explains the storage and routing structure used by `oli_embedded` and the legacy `superactivity` runtime.

For real deployments, the canonical storage model is AWS S3 or another S3-compatible object store configured the same way. MinIO is only the local-development stand-in used to emulate those buckets.

## Short Answer

- `/superactivity/...` is the legacy runtime path used by the embedded activity launcher and support scripts.
- `/super_media/...` is the logical browser path for activity support files such as `webcontent/...`.
- `media/...` and `superactivity/...` are object-storage key prefixes inside the support bucket.
- `<bucket>/superactivity/...` stores the base launcher HTML and scripts for legacy superactivity support.
- `<bucket>/media/webcontent/custom_activity/...` is the shared starter bundle source for the default `oli_embedded` activity.
- `<bucket>/bundles/<custom-activity-id>/webcontent/...` is the per-activity cloned bundle location for a bundle-backed embedded activity.

## URL Path vs. Bucket Key

There are two separate concepts in play:

1. Browser-facing URL paths, such as:
   - `/superactivity/...`
   - `/super_media/...`
   - `/buckets/torus-media-dev/...` in MinIO-backed local or preview setups

2. Bucket-relative object locations, such as:
   - `superactivity/scripts/jquery.min.js`
   - `media/webcontent/custom_activity/customactivity.js`
   - `bundles/<custom-activity-id>/webcontent/custom_activity/layout.html`

The browser does not ask for `media/...` directly. The browser asks for `/super_media/...` or `/superactivity/...`, and HAProxy, ingress, CloudFront, or direct storage URLs translate those requests to the underlying object-store layout.

## Canonical Storage Model

The canonical model is:

- Torus uses an S3 bucket for superactivity support assets
- that bucket contains at least these two required top-level prefixes:
  - `superactivity/...`
  - `media/webcontent/...`
- when a new default `oli_embedded` activity is created, its support files are cloned from `media/webcontent/custom_activity/...`
- the clone is written to `bundles/<custom-activity-id>/webcontent/...`
- browser-facing paths such as `/super_media/...` and `/superactivity/...` are translated to that bucket layout

In production-like environments, that bucket is usually AWS S3. See [`../starting/self-hosted.md`](../starting/self-hosted.md).

In local development, MinIO only emulates that same S3 bucket behavior. It is not the architectural source of truth.

## What Lives Where

### `<bucket>/superactivity/...`

This is the canonical bucket-relative location for the base launcher HTML and JavaScript used by custom activities.

Examples:

- `<bucket>/superactivity/embedded/index.html`
- `<bucket>/superactivity/scripts/jquery.min.js`

### `/superactivity/...`

This is the legacy runtime path for the base launcher HTML and JavaScript used by custom activities.

Examples:

- `/superactivity/embedded/index.html`
- `/superactivity/scripts/jquery.min.js`

In pure Phoenix development, `superactivity` can be served from `priv/static` because [`OliWeb.Endpoint`](../../lib/oli_web/endpoint.ex) exposes that directory through `Plug.Static`.

In HAProxy-backed local dev and some deployed environments, `/superactivity/...` may instead be proxied to object storage for compatibility. In local MinIO-backed dev, see [`../../scripts/dev/ha-proxy/haproxy_minio_docker.cfg`](../../scripts/dev/ha-proxy/haproxy_minio_docker.cfg).

So the answer to "didn't we previously have `/superactivity` served out of static space?" is:

- Yes, that legacy model still exists.
- But in some environments we now front that path through HAProxy or ingress instead of relying only on direct Phoenix static serving.

### `/super_media/...`

This is the logical browser path for mutable activity support files.

Examples:

- `/super_media/bundles/<custom-activity-id>/webcontent/custom_activity/customactivity.js`
- `/super_media/` for non-bundle-backed legacy fallback behavior

HAProxy or ingress rewrites `/super_media/...` to the bucket storage layout.

For local MinIO-backed dev, see [`../../scripts/dev/ha-proxy/haproxy_minio_docker.cfg`](../../scripts/dev/ha-proxy/haproxy_minio_docker.cfg):

- `/super_media/...` -> `/<bucket>/media/...`

For local external-origin dev routing, see [`../../scripts/dev/ha-proxy/haproxy_docker.cfg`](../../scripts/dev/ha-proxy/haproxy_docker.cfg).

### `<bucket>/media/webcontent/...`

This is the canonical bucket-relative location for shared starter content.

It is not a browser path and it is not new with this change. It is the storage-side layout used for activity support files.

The most important default prefix for `oli_embedded` is:

- `<bucket>/media/webcontent/custom_activity/`

That prefix is the shared starter bundle source used when a new default embedded activity is created. The create path in [`../../lib/oli/authoring/editing/activity_editor.ex`](../../lib/oli/authoring/editing/activity_editor.ex) currently expects to find the starter files there.

### `<bucket>/bundles/<custom-activity-id>/webcontent/...`

This is the per-activity clone location for bundle-backed embedded activities.

Examples:

- `<bucket>/bundles/1a225680-28ff-4a73-a32c-05ea53ce43e9/webcontent/custom_activity/layout.html`
- `<bucket>/bundles/1a225680-28ff-4a73-a32c-05ea53ce43e9/webcontent/uploads/existing.css`

Once an activity is bundle-backed, the browser-facing logical asset base becomes:

- `/super_media/bundles/<id>/...`

The authoring utilities that present this in the UI are in [`../../assets/src/components/activities/oli_embedded/utils.ts`](../../assets/src/components/activities/oli_embedded/utils.ts).

The `<bucket>` placeholder above means the actual configured support bucket, typically the value of `S3_MEDIA_BUCKET_NAME`.

For example, if `S3_MEDIA_BUCKET_NAME=torus-media-dev`, then:

- `<bucket>/superactivity/embedded/index.html` means `torus-media-dev/superactivity/embedded/index.html`
- `<bucket>/media/webcontent/custom_activity/customactivity.js` means `torus-media-dev/media/webcontent/custom_activity/customactivity.js`
- `<bucket>/bundles/<custom-activity-id>/webcontent/custom_activity/layout.html` means `torus-media-dev/bundles/<custom-activity-id>/webcontent/custom_activity/layout.html`

Local or preview environments may still expose bucket contents through a proxy URL shape such as `/buckets/<bucket>/...`, but that is only a URL convenience layer. It is not the canonical storage model.

## Current `oli_embedded` Starter-Bundle Model

Today, the default embedded activity model references these support files:

- `webcontent/custom_activity/customactivity.js`
- `webcontent/custom_activity/layout.html`
- `webcontent/custom_activity/controls.html`
- `webcontent/custom_activity/styles.css`
- `webcontent/custom_activity/questions.xml`

See [`../../assets/src/components/activities/oli_embedded/utils.ts`](../../assets/src/components/activities/oli_embedded/utils.ts).

When a new `oli_embedded` activity is created, the backend tries to:

1. detect that the model is still pointing at the default shared `custom_activity` content
2. list the starter files from `<bucket>/media/webcontent/custom_activity/`
3. copy them into a new `<bucket>/bundles/<custom-activity-id>/webcontent/` prefix
4. update the model to use that new `resourceBase`

That logic lives in [`../../lib/oli/authoring/editing/activity_editor.ex`](../../lib/oli/authoring/editing/activity_editor.ex).

If that clone fails, the activity falls back to a non-bundle-backed state and the authoring UI shows a warning.

The current implementation assumes a stable S3 location and that the support bucket already contains the two required bootstrap trees:

- `<bucket>/superactivity/...`
- `<bucket>/media/webcontent/...`

A local static-file fallback was considered, but it is not part of the current implementation.

## Local Development

For local `oli_embedded` work that needs the full runtime path behavior, use the MinIO-backed local emulation stack:

- [`../../docker-compose-haproxy.yml`](../../docker-compose-haproxy.yml)
- [`../../scripts/dev/ha-proxy/README.md`](../../scripts/dev/ha-proxy/README.md)
- [`../../scripts/dev/setup_minio_buckets.sh`](../../scripts/dev/setup_minio_buckets.sh)

### What This Stack Does

- Phoenix runs natively on the host, usually on `HTTP_PORT=8080`
- MinIO runs in Docker on `9000` and `9001` as the local S3 stand-in
- HAProxy runs in Docker on `80` and `443`
- HAProxy rewrites:
  - `/super_media/...` -> MinIO bucket `media/...`
  - `/superactivity/...` -> MinIO bucket `superactivity/...`
  - `/buckets/...` -> MinIO API
  - `/minio/...` -> MinIO console

See [`../../scripts/dev/ha-proxy/haproxy_minio_docker.cfg`](../../scripts/dev/ha-proxy/haproxy_minio_docker.cfg).

### Suggested Local Flow

1. Configure `oli.env` for proxy-backed local development.

Important settings:

- `HTTP_PORT=8080`
- `ENABLE_HTTPS=false`
- MinIO S3 settings:
  - `AWS_S3_SCHEME=http`
  - `AWS_S3_HOST=localhost`
  - `AWS_S3_PORT=9000`
- local credentials:
  - `AWS_ACCESS_KEY_ID=...`
  - `AWS_SECRET_ACCESS_KEY=...`
- media bucket:
  - `S3_MEDIA_BUCKET_NAME=torus-media-dev`

2. Generate the local HAProxy certificate:

```bash
./scripts/dev/generate_haproxy_localhost_cert.sh
```

3. Start the local proxy-backed services:

```bash
docker compose -f docker-compose-haproxy.yml build haproxy
docker compose -f docker-compose-haproxy.yml up -d
```

4. Create the MinIO buckets:

```bash
./scripts/dev/setup_minio_buckets.sh
```

5. Start Phoenix natively:

```bash
mix phx.server
```

6. Open:

- `https://localhost` for Torus
- `https://localhost/minio` for the MinIO console through HAProxy, or `http://localhost:9001` directly

### One Important Limitation

Bucket creation is automated by [`../../scripts/dev/setup_minio_buckets.sh`](../../scripts/dev/setup_minio_buckets.sh), but the default embedded starter files still must exist under:

- `media/webcontent/custom_activity/`

If those objects are missing from the support bucket, new `oli_embedded` activity creation will fall back and show the starter-bundle warning.

## Answering The Common Questions Directly

### Are these bucket names or directories new with this change?

No. The bucket itself is part of the existing object-storage model. What may feel new is the proxy URL shape `/buckets/<bucket>/...` in MinIO-backed preview and local setups.

That path is just ingress or HAProxy exposing bucket contents through the app host. It is not a new internal application storage convention.

### Didn't we previously have `/superactivity` served out of static space for base HTML pages and scripts?

Yes. That legacy behavior still exists through Phoenix static serving from `priv/static`. But some environments now proxy `/superactivity/...` to object storage instead, especially local MinIO-backed or preview setups that are trying to emulate the real S3-backed model more closely.

So `/superactivity` is still the same logical runtime path, even though the serving mechanism can differ by environment.

### What is `<bucket>/media/webcontent`?

That is the bucket-relative storage location for the shared starter bundle objects.

For example:

- `S3_MEDIA_BUCKET_NAME=torus-media-dev`
- object key: `media/webcontent/custom_activity/customactivity.js`

Together those represent the default starter bundle source object:

- `torus-media-dev/media/webcontent/custom_activity/customactivity.js`

When a new default embedded activity is created, those starter files are cloned into that activity's own independent location, for example:

- `torus-media-dev/bundles/<custom-activity-id>/webcontent/custom_activity/customactivity.js`

That fits the existing course digest bundle approach and keeps each embedded activity instance independent of any other instance.

In production AWS S3 usage, you would usually not talk about this as a `/buckets/...` path at all. You would instead think in terms of:

- bucket name: for example `torus-media`
- object key: for example `media/webcontent/custom_activity/customactivity.js`
- public media base URL: `MEDIA_URL`

## Related Files

- [`../../lib/oli/authoring/editing/activity_editor.ex`](../../lib/oli/authoring/editing/activity_editor.ex)
- [`../../lib/oli_web/controllers/legacy_superactivity_controller.ex`](../../lib/oli_web/controllers/legacy_superactivity_controller.ex)
- [`../../assets/src/components/activities/oli_embedded/utils.ts`](../../assets/src/components/activities/oli_embedded/utils.ts)
- [`../../scripts/dev/ha-proxy/README.md`](../../scripts/dev/ha-proxy/README.md)
- [`../../docs/preview-environments.md`](../../docs/preview-environments.md)
