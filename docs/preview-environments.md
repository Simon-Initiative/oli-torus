# Preview Environments on k3s

This document explains how pull request preview environments are built and operated after the migration to k3s and the adoption of Kustomize-based manifests.

## URL Pattern

Every PR is exposed at `https://pr-<number>.<domain>`, where `<domain>` defaults to `plasma.oli.cmu.edu`. Override the domain by setting the repository variable `PREVIEW_DOMAIN` (used by the deploy workflow when it composes the overlay literals).

## GitHub Workflows

- `.github/workflows/preview-deploy.yml` builds a PR image, pushes it to GHCR, applies namespace policies, and now runs `kustomize build devops/kustomize/overlays/preview | kubectl apply -f -` on PR open/sync events (after editing the overlay literals for the active PR number).
- `.github/workflows/preview-teardown.yml` deletes the namespace when the PR closes (`kubectl delete namespace pr-<n>`). The preview manifests are idempotent, so re-running the deploy workflow reconciles existing previews without uninstall steps.
- Both workflows also support manual runs via `workflow_dispatch`; supply the `ref`
  (branch/tag) and `preview_id` (namespace/host slug) to deploy or clean up a
  branch outside the PR flow.

### Required Secrets and Variables

Set these in repository settings before enabling the workflows:

- `SIMON_BOT_PERSONAL_ACCESS_TOKEN` – long-lived PAT with at least `read:packages` scope used to create per-namespace GHCR pull secrets. Replace with your own service user if desired.
- Optional repository variable `PREVIEW_DOMAIN` if you need a host suffix other than `plasma.oli.cmu.edu`.
- Image publishes use the ephemeral `GITHUB_TOKEN`, so no additional secrets are required.

## Kustomize Layout

The manifests live under `devops/kustomize/`:

- `base/` – generic resources for the app Deployment/Service (with an init container that runs `Oli.Release.setup`), Postgres & MinIO StatefulSets, Traefik ingress + middleware, and the MinIO bucket job. The base references the shared secret generated from `devops/default.env`.
- `overlays/preview/` – sample overlay that merges PR-specific values (namespace, image tag, host literals, etc.). `params.env` feeds ingress host substitutions, and `app-overrides.env` overrides environment keys like `HOST`/`MEDIA_URL` inside the generated secret.

To create an overlay for a PR at runtime:

1. Copy `devops/kustomize/overlays/preview/` (or modify it in-place) and set the values in `params.env` **and** `app-overrides.env` to the target slug and domain (the deploy workflow rewrites both automatically).
2. Run `kustomize build --load-restrictor LoadRestrictionsNone devops/kustomize/overlays/preview | kubectl apply -f -` with `KUBECONFIG` pointing at the k3s cluster.
3. (Optional) After pods become ready, rerun the MinIO bucket job by deleting the corresponding Job resource and re-applying the overlay.

`devops/default.env` seeds the application environment secret. `app-overrides.env` supplies the concrete `HOST`/`MEDIA_URL` overrides (and any additional key/value pairs you append).

## Supporting Services

Each preview release installs dedicated Postgres (pgvector) and MinIO instances alongside the application:

- Persistent volumes are created via the k3s local-path provisioner (default 10 GiB for both services).
- The application init container runs `Oli.Release.setup` before the Phoenix server starts, mirroring the Docker Compose initialisation step.
- The MinIO bucket job provisions `torus-media`, `torus-xapi`, and `torus-blob-dev` and sets public policies. Both jobs use elevated resource limits defined in the manifests to avoid repeated OOMs.
- Supporting workloads request generous CPU/memory while remaining under the namespace LimitRange cap (4 CPU / 16 GiB).

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
- Application pods (including the setup init container) and the bucket job all mount the `app-env` secret generated from `devops/default.env`; update the overlay literals when introducing new env keys.
- Postgres and MinIO resources are namespace-scoped, so cleanup on failure should remove related PVCs (`kubectl delete pvc -n pr-<n> -l app.kubernetes.io/component=minio`).
- Remember to trust the pod network on the k3s node (e.g., add `cni0`/`flannel.1` to the trusted zone and open Traefik NodePorts) so Traefik can reach preview pods.
- Manual clean-up: run `kubectl delete namespace pr-<number>` if a workflow fails.
- Record significant changes to infra assets in `devops/change-log.md`.
