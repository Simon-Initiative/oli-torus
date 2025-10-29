# OLI Torus Preview Helm Chart

The chart at `devops/helm/app/` deploys a full pull-request preview stack (application, Postgres, and MinIO) into k3s.

## Usage

Render manifests locally:

```bash
helm template pr-123 devops/helm/app \
  --set prNumber=123 \
  --set image.repository=ghcr.io/org/app \
  --set image.tag=pr-123
```

Install to the cluster:

```bash
helm upgrade --install pr-123 devops/helm/app \
  --namespace pr-123 --create-namespace \
  --set prNumber=123 \
  --set image.repository=ghcr.io/org/app \
  --set image.tag=pr-123
```

Override `previewDomain` if you use a non-default host suffix. Additional configuration options are documented in `values.yaml`.

## Configuration highlights

- **Supporting services** – Postgres (pgvector) and MinIO are bundled as StatefulSets with persistent volumes. Bucket creation and public policies mirror the Docker Compose workflow, and default requests/limits are provided so namespace quotas are satisfied.
- **Application environment** – `devops/default.env` seeds the generated secret. Override keys with:
  ```yaml
  appEnv:
    overrides:
      ADMIN_PASSWORD: secure-change-me
      MEDIA_URL: "https://custom.example/minio/torus-media"
  ```
- **Database setup job** – After each install/upgrade, a hook job runs the release setup command (`Oli.Release.setup`). Disable or customise via `releaseSetup.*` values (including resource requests/limits).
- **Image overrides** – Set `image.repository` and `image.tag` per PR; GitHub Actions supplies these automatically.
- **Scaling/resources** – Adjust container sizing via `resources`, `postgres.resources`, and `minio.resources`; tweak PVC sizes under the respective `persistence` blocks.

See `values.yaml` for all available knobs (e.g., disabling supporting services, customizing MinIO buckets, or injecting additional environment variables with `extraEnv`/`extraEnvFrom`).
