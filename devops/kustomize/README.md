# Kustomize Manifests for Preview Environments

The resources in this directory replace the former Helm chart and are consumed
by both CI and local operators to provision pull-request previews.

## Layout

- `base/` – canonical manifests for the application Deployment/Service,
  supporting Postgres and MinIO StatefulSets, Traefik ingress + middleware, and
  helper Jobs (release setup and MinIO bucket seeding). The base also includes a
  `secretGenerator` that renders the application environment variables from
  `devops/default.env`.
- `overlays/preview/` – example overlay showing how to set the namespace, image
  tag, ingress host, secret overrides, and image pull secrets for a single PR.
  The overlay uses `behavior: merge` on the secret generator and strategic
  merge patches for ingress and workload tweaks.

## Day-to-day usage

1. Copy or edit the overlay (especially `params.env`) so the placeholder strings
   (`PLACEHOLDER`, `DOMAIN_PLACEHOLDER`) are replaced with the live PR number and
   domain. The GitHub workflow overwrites `params.env` automatically; locally you
   can edit the file by hand or recreate it with `cat <<EOF > params.env ...`.
2. Apply namespace policies:
   ```bash
   devops/scripts/apply-preview-policies.sh pr-123
   ```
3. Deploy the preview (after adjusting placeholders):
  ```bash
  kustomize build --load-restrictor LoadRestrictionsNone devops/kustomize/overlays/preview | kubectl apply -f -
  ```
4. Clean up by deleting the namespace when the PR closes:
   ```bash
   kubectl delete namespace pr-123
   ```

### Customisation

- To set additional environment variables, add literals to the overlay’s
  `secretGenerator` section.
- Update the ingress patches if your Traefik deployment expects different
  annotations.
- Use `kustomize edit set image ghcr.io/simon-initiative/oli-torus=ghcr.io/simon-initiative/oli-torus:<tag>`
  inside the overlay directory to point at a specific image.
- Adjust pod resources and PVC sizes by editing the manifests in `base/` or by
  applying overlay-specific patches.

Run `kustomize build devops/kustomize/overlays/preview` whenever you need to
inspect the rendered YAML before applying it.
