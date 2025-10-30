# k3s Preview Environment Implementation Plan

This plan translates the high-level migration approach in `devops/k8s_migration_plan.md` into concrete execution steps. It is organized by phases, with responsibilities split between **Codex** (repository automation/support work) and the **DevOps engineer** (cluster/runtime operations). Complete the phases sequentially unless otherwise noted.

---

## Phase 0 – Alignment & Readiness

**Codex**
- Validate repository layout supports infra assets (e.g., ensure `devops/` hosts the Kustomize base/overlays and supporting manifests). Create tracking issues/tasks (GitHub Projects or similar) mirroring the phases below.

**DevOps engineer**
- Confirm target host specifications: 4+ vCPU, 8+ GB RAM, 80+ GB SSD free; Amazon Linux 2023 (or current production baseline). Document host inventory and access controls.
- Harden the OS:
  - Ensure only key-based SSH for `sudo`-capable users.
  - Apply latest patches (`sudo dnf update -y`), enable automatic updates (`sudo systemctl enable --now dnf-automatic.timer`).
  - Verify firewall rules allow inbound `tcp/22`, `tcp/80`, `tcp/443`; allow NodePort range `30000-32767` from HAProxy host only.
- Capture current Docker Compose deployment diagram and rollback steps for incident response (link in runbook).

Exit criteria: environment readiness documented; rollback notes captured.

---

## Phase 1 – k3s Control Plane Setup

**Codex**
- Provide k3s install checklist in repository docs (`devops/README.md` or similar) once Phase 1 completes to ease future re-runs.

**DevOps engineer**
- Install k3s server on the target host:
  ```bash
  curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    --disable=servicelb
  sudo systemctl enable --now k3s
  ```
- Verify cluster health:
  ```bash
  sudo kubectl get nodes
  sudo kubectl get pods -A
  ```
  Confirm `traefik`, `coredns`, `local-path-provisioner` are ready.
- Store `/etc/rancher/k3s/k3s.yaml` securely; create read-only copy for CI runner user (`sudo install -m 600 -o runner -g runner /etc/rancher/k3s/k3s.yaml /home/runner/.kube/config`).
- Document node token location (`/var/lib/rancher/k3s/server/node-token`) for future worker joins.

Exit criteria: single-node cluster online, kubeconfig accessible to runner account.

---

## Phase 2 – Edge Routing & DNS Integration

**Codex**
- None (supporting docs already captured in migration plan).

**DevOps engineer**
- Configure Traefik service to NodePort if not already:
  ```bash
  sudo kubectl -n kube-system patch svc traefik \
    -p '{"spec":{"type":"NodePort","ports":[{"name":"web","port":80,"nodePort":30080}]}}'
  ```
  Adjust `nodePort` if 30080 unavailable; record chosen value.
- Update HAProxy configuration on the edge host:
  - Add/adjust `frontend https-in` default backend to point to Traefik NodePort (`server k3snode <node-ip>:<nodePort> check`).
  - Validate HAProxy config: `sudo haproxy -c -f /etc/haproxy/haproxy.cfg`, then reload.
- Ensure wildcard DNS (`*.plasma.oli.cmu.edu` or final hostname) points at HAProxy public IP. If new subdomain is required, create corresponding record.
- Smoke test routing: `curl -H "Host: placeholder.plasma.oli.cmu.edu" https://<haproxy-ip>` should reach Traefik default 404.

Exit criteria: HAProxy routes preview hostnames to Traefik; DNS updated.

---

## Phase 3 – Cluster Services, Security, and Quotas

**Codex**
- Author baseline manifests under `devops/k8s/`:
  - `namespaces/pr-template.yaml` for templated namespace creation.
  - `rbac/pr-admin.yaml` defining ServiceAccount/RoleBinding for GitHub Actions.
  - `policies/resource-quota.yaml` and `policies/network-policy.yaml` aligned with migration guidance.
- Provide README snippets describing how CI applies these manifests.
- Supply helper script `devops/scripts/apply-preview-policies.sh` for namespace bootstrap via CI.
- Translate `devops/default.env` into a Kustomize `secretGenerator` so application environment variables are sourced from a Kubernetes secret by default, while allowing overlay-level overrides.

- Apply infrastructure RBAC baseline:
  ```bash
  kubectl apply -f devops/k8s/rbac/pr-admin.yaml
  ```
- Confirm the CI runner has `docker`, `kubectl`, `kustomize`, and `envsubst` available; install if missing.
- Validate that the deploy workflow can create `ghcr-creds` secrets in PR namespaces (requires `SIMON_BOT_PERSONAL_ACCESS_TOKEN` or equivalent PAT with `read:packages` scope stored in GitHub secrets).
- Decide on TLS strategy:
  - If continuing HAProxy-managed TLS, skip cert-manager.
  - If cluster-managed certs desired, install cert-manager using helm commands from the migration plan and create `ClusterIssuer` secrets (API tokens, email).
- Document applied resources and location of secrets for audits.
- When onboarding new namespaces manually, run `devops/scripts/apply-preview-policies.sh pr-<n>` to guarantee quota and NetworkPolicy are applied consistently.

Exit criteria: cluster RBAC/policies in place; registry access configured; TLS approach confirmed.

---

## Phase 4 – Kustomize Base & Overlay Authoring

**Codex**
- Scaffold Kustomize assets under `devops/kustomize/`:
  - `base/` contains canonical manifests for the app Deployment/Service, Postgres & MinIO StatefulSets, Traefik ingresses/middlewares, release setup job, and MinIO bucket job. Ensure the base references the shared `app-env` secret generator fed by `devops/default.env`.
  - `overlays/preview/` demonstrates how to merge PR-specific values (namespace, image tag, ingress host, secret overrides, image pull secrets). Include example patches for forwarded header annotations and MinIO console routing.
  - Keep resource requests/limits generous (3 CPU/12 Gi app cap, 2 CPU/8 Gi Postgres, 2 CPU/6 Gi MinIO, etc.) while ensuring they stay under the namespace LimitRange ceiling.
- Document how to tune the overlay (image names, host literal, additional env vars) in `docs/preview-environments.md` and add a README snippet explaining `kustomize build … | kubectl apply -f -`.
- Provide `make preview-deploy` or script snippets if helpful for local testing (`kustomize build devops/kustomize/overlays/preview | kubectl apply -f -`).

**DevOps engineer**
- Review default resource requests and PVC sizes relative to cluster capacity; feedback any adjustments required for production parity.
- Validate generated manifests locally:
  ```bash
  kustomize build devops/kustomize/overlays/preview
  ```
  Ensure the rendered YAML matches expectations (ingress host, image tags, secret literals) before CI adopts it.

Exit criteria: Kustomize base/overlay merged; DevOps signs off on rendered manifests.

---

## Phase 5 – CI/CD Integration

**Codex**
- Implement GitHub Actions workflows:
  - `preview-deploy.yml` triggered on PR open/sync to build the image, push to GHCR, create/patch the namespace, apply quotas/policies, template the overlay (update `PLACEHOLDER` tokens), and run `kustomize build devops/kustomize/overlays/preview | kubectl apply -f -`.
  - `preview-teardown.yml` triggered on PR close to delete the namespace (which removes all preview resources).
  - Include steps to copy kubeconfig from the runner path (`export KUBECONFIG=/etc/rancher/k3s/k3s.yaml`) and install `kustomize` (or use `kubectl kustomize`).
- Workflows should lean on the job-scoped `GITHUB_TOKEN` for building/pushing images, while using `secrets.SIMON_BOT_PERSONAL_ACCESS_TOKEN` (or an equivalent long-lived PAT) strictly for populating namespace pull secrets.
- Document workflow behaviour in repo (e.g., `docs/preview-environments.md`) so developers know preview URL patterns, which overlay fields must be substituted per PR (host, namespace, tag), and how to append extra environment variables via the overlay’s `secretGenerator`.

**DevOps engineer**
- Prepare runner environment:
  - Ensure the self-hosted runner on the k3s node is registered with the `plasma` label (or the exact name referenced in the workflow).
  - Grant runner user read access to kubeconfig; install `kustomize` (or confirm `kubectl kustomize` is available) and ensure the binary is on the runner’s `PATH`.
- Create GitHub secrets:
  - `SIMON_BOT_PERSONAL_ACCESS_TOKEN` (or equivalent long-lived PAT with `read:packages`) used to seed namespace pull secrets.
  - Optional DNS API tokens if cert-manager/ExternalDNS used.
- Test workflows:
  - Open test PR; observe action logs.
  - Verify image pushes succeed (`docker pull` from GHCR).
  - Confirm namespace and workloads created (`kubectl get ns pr-<n>` and `kubectl -n pr-<n> get deploy,sts,ing`).
- Configure cleanup safeguard: add scheduled workflow (monthly) to list and prune orphaned namespaces; Codex can script if requested.

Exit criteria: CI workflows run end-to-end creating functional preview environment and tearing down on PR close.

---

## Phase 6 – Migration Cutover & Validation

**Codex**
- Provide smoke-test script template (`devops/scripts/smoke-test-preview.sh`) hitting health endpoints (HTTP 200) for use in CI and manual validation.
- Update documentation referencing preview URLs in developer onboarding guides.

**DevOps engineer**
- Coordinate freeze window (30–60 minutes) to disable existing Docker Compose preview automation while verifying k3s pipeline.
- Run smoke-test script against new preview release; share output with stakeholders.
- Inform app team of new preview URL format and confirm their access.
- Monitor cluster resources (`kubectl top pods`, `kubectl describe node`) during first few PRs; adjust quotas/limits if necessary.
- Decommission old Docker Compose tooling after two weeks of stable k3s previews: archive compose files, disable old GitHub workflows.

Exit criteria: preview environments exclusively served from k3s; legacy pipeline retired.

---

## Phase 7 – Post-Migration Enhancements (Optional)

**Codex**
- Track backlog items:
  - Add automated validation for Kustomize overlays (e.g., `kustomize build` + `kubectl apply --dry-run=server` in CI).
  - Add ExternalDNS integration if unique DNS records per PR desired.
  - Add lint/unit tests for rendered manifests.

**DevOps engineer**
- Evaluate storage backend upgrade (Longhorn/CSI) when multiple worker nodes introduced; plan data migration.
- Implement node monitoring/alerting (Prometheus node exporter, Grafana dashboards).
- Review security posture quarterly: rotate registry tokens, audit namespaces, ensure NetworkPolicies enforced.

Exit criteria: backlog items prioritized; monitoring/security tasks scheduled.

---

## Milestone & Communication Guidance

- Hold weekly sync between Codex and DevOps engineer until Phase 5 completes; switch to bi-weekly afterwards.
- Maintain shared checklist (Notion/Jira) mapping to phases with owners and due dates.
- Document every change in `devops/change-log.md` with date, owner, summary, and rollback instructions.

Completion of all mandatory phases (0–6) delivers the k3s-based PR preview environment aligned with the migration plan. Phase 7 tracks continuous improvements.
