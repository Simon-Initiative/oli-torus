# Preview Environments on k3s

This document explains how pull request preview environments are built and operated after the migration to k3s.

## URL Pattern

Every PR is exposed at `https://pr-<number>.<domain>`, where `<domain>` defaults to `plasma.oli.cmu.edu`. Override the domain by setting the repository variable `PREVIEW_DOMAIN`.

## GitHub Workflows

- `.github/workflows/preview-deploy.yml` builds a PR image, pushes it to GHCR, applies namespace policies, and deploys the Helm chart on PR open/sync events.
- `.github/workflows/preview-teardown.yml` removes the release and namespace when the PR closes.

### Required Secrets and Variables

Set these in repository settings before enabling the workflows:

- `SIMON_BOT_PERSONAL_ACCESS_TOKEN` – long-lived PAT with at least `read:packages` scope used to create per-namespace GHCR pull secrets. Replace with your own service user if desired.
- Optional repository variable `PREVIEW_DOMAIN` if you need a host suffix other than `plasma.oli.cmu.edu`.
- Image publishes use the ephemeral `GITHUB_TOKEN`, so no additional secrets are required.

## Supporting Services

Each preview release installs dedicated Postgres (pgvector) and MinIO instances alongside the application:

- Persistent volumes are created via the k3s local-path provisioner (10 GiB default for both services).
- A post-install job seeds MinIO buckets (`torus-media`, `torus-xapi`, `torus-blob-dev`) and grants public access where required.
- Connection details are injected into the app via the generated environment secret so no manual setup is required.
- Another Helm hook runs the Elixir release setup task (`/app/bin/oli eval "Oli.Release.setup"`) after each deployment to mirror Docker Compose initialisation.
- Supporting services and hook jobs declare default resource requests/limits so they satisfy namespace quotas; tune them via `postgres.resources`, `minio.resources`, `minio.bucketJob.resources`, or `releaseSetup.resources` as needed.

Customise storage sizes, images, or bucket policies through `values.yaml` (`postgres.*`, `minio.*`).

## Environment Configuration

`devops/default.env` seeds the Helm-managed secret. To override keys for a specific deployment, set `appEnv.overrides` in your values (or via `--set-string`):

```yaml
appEnv:
  overrides:
    ADMIN_PASSWORD: "more-secure-pass"
    MEDIA_URL: "https://custom.example.edu/minio/torus-media"
extraEnv:
  - name: FEATURE_FLAG_EXAMPLE
    value: "true"
```

The chart automatically derives `HOST`, `DATABASE_URL`, `AWS_S3_*`, and `MEDIA_URL` unless explicitly overridden.

MinIO assets are served from `https://pr-<PR>.plasma.oli.cmu.edu/minio/<bucket>/...`, and the MinIO console is exposed at `https://pr-<PR>.plasma.oli.cmu.edu/minio`.

## Cluster Preparation Checklist

The DevOps engineer must apply the following once per cluster (see `devops/plan.md` Phase 3):

```bash
kubectl apply -f devops/k8s/rbac/pr-admin.yaml
```

For each new PR namespace the CI workflow runs:

```bash
devops/scripts/apply-preview-policies.sh pr-123
```

The script templatises quota, limit range, and network policy manifests and applies them to the namespace. Namespace pull secrets are refreshed automatically using `SIMON_BOT_PERSONAL_ACCESS_TOKEN`.

## Smoke Testing

Use `devops/scripts/smoke-test-preview.sh` to validate a deployed preview:

```bash
devops/scripts/smoke-test-preview.sh https://pr-123.plasma.oli.cmu.edu/healthz
```

The script exits non-zero if any probe fails. Integrate it into CI if desired.

## Operational Notes

- Preview namespaces enforce resource quotas and default limits aligned with `devops/k8s/policies/`.
- Each Helm release uses the image tag `pr-<number>` published to GHCR by the deploy workflow.
- Postgres and MinIO pods are namespaced per PR (`pr-<n>`), so cleanup on failure should remove related PVCs (`kubectl delete pvc -n pr-<n> -l app.kubernetes.io/instance=oli-torus-preview-<n>`).
- Remember to trust the pod network on the k3s node (e.g., add `cni0`/`flannel.1` to the trusted zone and open Traefik NodePorts) so Traefik can reach preview pods.
- Manual clean-up: run `helm uninstall pr-<number> -n pr-<number>` and `kubectl delete ns pr-<number>` if a workflow fails.
- Record significant changes to infra assets in `devops/change-log.md`.
