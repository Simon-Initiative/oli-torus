# Preview Environments on k3s

This document explains how pull request preview environments are built and operated after the migration to k3s.

## URL Pattern

Every PR is exposed at `https://pr-<number>.<domain>`, where `<domain>` defaults to `plasma.oli.cmu.edu`. Override the domain by setting the repository variable `PREVIEW_DOMAIN`.

## GitHub Workflows

- `.github/workflows/preview-deploy.yml` builds a PR image, pushes it to GHCR, applies namespace policies, and deploys the Helm chart on PR open/sync events.
- `.github/workflows/preview-teardown.yml` removes the release and namespace when the PR closes.

## Supporting Services

Each preview release installs dedicated Postgres (pgvector) and MinIO instances alongside the application:

- Persistent volumes are created via the k3s local-path provisioner (10 GiB default for both services).
- A post-install job seeds MinIO buckets (`torus-media`, `torus-xapi`, `torus-blob-dev`) and grants public access where required.
- Connection details are injected into the app via the generated environment secret so no manual setup is required.

Customise storage sizes, images, or bucket policies through `values.yaml` (`postgres.*`, `minio.*`).

## Environment Configuration

`devops/default.env` seeds the Helm-managed secret. To override keys for a specific deployment, set `appEnv.overrides` in your values (or via `--set-string`):

```yaml
appEnv:
  overrides:
    ADMIN_PASSWORD: "more-secure-pass"
    MEDIA_URL: "https://custom.example.edu/s3/torus-media"
extraEnv:
  - name: FEATURE_FLAG_EXAMPLE
    value: "true"
```

The chart automatically derives `HOST`, `DATABASE_URL`, `AWS_S3_*`, and `MEDIA_URL` unless explicitly overridden.

## Cluster Preparation Checklist

The DevOps engineer must apply the following once per cluster (see `devops/plan.md` Phase 3):

```bash
kubectl apply -f devops/k8s/rbac/pr-admin.yaml
```

For each new PR namespace the CI workflow runs:

```bash
devops/scripts/apply-preview-policies.sh pr-123
```

The script templatises quota, limit range, and network policy manifests and applies them to the namespace.

GHCR credentials are created per namespace by the deploy workflow using the configured `CR_PAT`/`GH_USER` secrets; no manual secret rotation is required unless those credentials change.
The workflow logs in for image pushes with the ephemeral `GITHUB_TOKEN`, so no additional secret is required for publishing images.

## Smoke Testing

Use `scripts/smoke-test-preview.sh` to validate a deployed preview:

```bash
scripts/smoke-test-preview.sh https://pr-123.plasma.oli.cmu.edu/healthz
```

The script exits non-zero if any probe fails. Integrate it into CI if desired.

## Operational Notes

- Preview namespaces enforce resource quotas and default limits aligned with `devops/k8s/policies/`.
- Each Helm release uses the image tag `pr-<number>` published to GHCR by the deploy workflow.
- Postgres and MinIO pods are namespaced per PR (`pr-<n>`), so cleanup on failure should remove related PVCs (`kubectl delete pvc -n pr-<n> -l app.kubernetes.io/instance=oli-torus-preview-<n>`).
- Manual clean-up: run `helm uninstall pr-<number> -n pr-<number>` and `kubectl delete ns pr-<number>` if a workflow fails.
- Record significant changes to infra assets in `devops/change-log.md`.
