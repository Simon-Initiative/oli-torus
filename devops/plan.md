# k3s Preview Environment Implementation Plan

This plan translates the high-level migration approach in `devops/k8s_migration_plan.md` into concrete execution steps. It is organized by phases, with responsibilities split between **Codex** (repository automation/support work) and the **DevOps engineer** (cluster/runtime operations). Complete the phases sequentially unless otherwise noted.

---

## Phase 0 – Alignment & Readiness

**Codex**
- Validate repository layout supports infra assets (e.g., ensure `devops/` directory hosts Helm and supporting manifests). Create tracking issues/tasks (GitHub Projects or similar) mirroring the phases below.

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
  - `policies/resource-quota.yaml`, `policies/limit-range.yaml`, and `policies/network-policy.yaml` aligned with migration guidance.
- Provide README snippets describing how CI applies these manifests.
- Supply helper script `devops/scripts/apply-preview-policies.sh` for namespace bootstrap via CI.
- Translate `devops/default.env` into chart defaults so application environment variables are sourced from a Kubernetes secret by default, while allowing overrides.

- Apply infrastructure RBAC baseline:
  ```bash
  kubectl apply -f devops/k8s/rbac/pr-admin.yaml
  ```
- Confirm the CI runner has `docker`, `kubectl`, `helm`, and `envsubst` available; install if missing.
- Validate that the deploy workflow can create `ghcr-creds` secrets in PR namespaces (requires `SIMON_BOT_PERSONAL_ACCESS_TOKEN` or equivalent PAT with `read:packages` scope stored in GitHub secrets).
- Decide on TLS strategy:
  - If continuing HAProxy-managed TLS, skip cert-manager.
  - If cluster-managed certs desired, install cert-manager using helm commands from the migration plan and create `ClusterIssuer` secrets (API tokens, email).
- Document applied resources and location of secrets for audits.
- When onboarding new namespaces manually, run `devops/scripts/apply-preview-policies.sh pr-<n>` to guarantee quota, limits, and NetworkPolicy are applied consistently.

Exit criteria: cluster RBAC/policies in place; registry access configured; TLS approach confirmed.

---

## Phase 4 – Helm Chart Authoring

**Codex**
- Scaffold Helm chart at `devops/helm/app/`:
  - Templates for Deployment, Service, and Ingress for the application (host `{{ printf "pr-%s.plasma.oli.cmu.edu" .Values.prNumber }}`).
  - Bundle preview-friendly Postgres (pgvector image) and MinIO StatefulSets with PVCs, Services, and a bucket-initialisation job mirroring `devops/docker-compose.yml`.
  - Generate an application env secret derived from `devops/default.env`, with support for overrides via `values.yaml`.
  - Add a post-install/upgrade Job that runs the Elixir release setup task (`/app/bin/oli eval "Oli.Release.setup"`) so the database schema mirrors compose deployments.
  - Provide sensible default resource requests/limits for supporting workloads (Postgres, MinIO, and the bucket/setup jobs) to comply with namespace quotas while remaining overrideable.
  - Values supporting `image.repository`, `image.tag`, replica count (default 1), environment variables, and optional resource overrides for supporting services.
  - Include `README.md` with usage examples:
    ```bash
    helm upgrade --install pr-123 devops/helm/app \
      --namespace pr-123 --create-namespace \
      --set prNumber=123 \
    --set image.repository=ghcr.io/org/app \
    --set image.tag=pr-123
  ```
- Add `helm lint` step to project docs and optionally a CI job for chart validation.

**DevOps engineer**
- Review chart defaults against infrastructure limits (CPU/memory). Supply Codex with required secret names and config keys.
- After Codex delivers chart, perform manual validation:
  ```bash
  helm template pr-0 devops/helm/app --set prNumber=0
  ```
  Ensure generated manifests match expectations (Ingress host, service ports).

Exit criteria: Helm chart merged; validated by DevOps in dry run.

---

## Phase 5 – CI/CD Integration

**Codex**
- Implement GitHub Actions workflows:
  - `preview-deploy.yml` triggered on PR open/sync to build image, push to GHCR, create namespace (idempotent), apply quotas/policies, run `helm upgrade --install`.
  - `preview-teardown.yml` triggered on PR close to uninstall release and delete namespace.
  - Include steps to copy kubeconfig from runner path (export `KUBECONFIG=/etc/rancher/k3s/k3s.yaml`) and run `helm/kubectl`.
- Workflows should lean on the job-scoped `GITHUB_TOKEN` for building/pushing images, while using `secrets.SIMON_BOT_PERSONAL_ACCESS_TOKEN` (or an equivalent long-lived PAT) strictly for populating namespace pull secrets.
- Document workflow behaviour in repo (e.g., `docs/preview-environments.md`) so developers know preview URL patterns, available Helm values (Postgres/MinIO tuning), and how to override the default environment secret via `appEnv.overrides`.

**DevOps engineer**
- Prepare runner environment:
  - Ensure the self-hosted runner on the k3s node is registered with the `plasma` label (or the exact name referenced in the workflow).
  - Grant runner user read access to kubeconfig; install Helm via `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash` and ensure the binary is on the runner’s `PATH`.
- Create GitHub secrets:
  - `SIMON_BOT_PERSONAL_ACCESS_TOKEN` (or equivalent long-lived PAT with `read:packages`) used to seed namespace pull secrets.
  - Optional DNS API tokens if cert-manager/ExternalDNS used.
- Test workflows:
  - Open test PR; observe action logs.
  - Verify image pushes succeed (`docker pull` from GHCR).
  - Confirm namespace/Helm release created (`kubectl get ns pr-<n>`).
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
  - Automate Helm chart publishing to GHCR as OCI artifact.
  - Add ExternalDNS integration if unique DNS records per PR desired.
  - Add lint/unit tests for chart templates.

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
