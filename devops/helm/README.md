# OLI Torus Preview Helm Chart

The chart at `devops/helm/app/` deploys a pull-request preview environment in k3s.

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
