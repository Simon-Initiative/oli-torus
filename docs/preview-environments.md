# Preview Environments on k3s

This document explains how pull request preview environments are built and operated after the migration to k3s.

## URL Pattern

Every PR is exposed at `https://pr-<number>.<domain>`, where `<domain>` defaults to `plasma.oli.cmu.edu`. Override the domain by setting the repository variable `PREVIEW_DOMAIN`.

## GitHub Workflows

- `.github/workflows/preview-deploy.yml` builds a PR image, pushes it to GHCR, applies namespace policies, and deploys the Helm chart on PR open/sync events.
- `.github/workflows/preview-teardown.yml` removes the release and namespace when the PR closes.

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
scripts/smoke-test-preview.sh https://pr-123.plasma.oli.cmu.edu/health
```

The script exits non-zero if any probe fails. Integrate it into CI if desired.

## Operational Notes

- Preview namespaces enforce resource quotas and default limits aligned with `devops/k8s/policies/`.
- Each Helm release uses the image tag `pr-<number>` published to GHCR by the deploy workflow.
- Manual clean-up: run `helm uninstall pr-<number> -n pr-<number>` and `kubectl delete ns pr-<number>` if a workflow fails.
- Record significant changes to infra assets in `devops/change-log.md`.
