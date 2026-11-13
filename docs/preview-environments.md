# Pull Request Previews

## Build and Deployment Records

`.github/workflows/build-preview-image.yml` builds and publishes preview images.
Each PR keeps its own image tag, `preview-<PR number>-<head SHA, first 7 characters>`,
and URL, `https://preview-<PR number>.plasma.oli.cmu.edu/`.

Both the automatic and manual jobs record deployments under the shared GitHub
environment `plasma-previews`. Each deployment references its PR head SHA and
supplies its own `environment_url`. Preview deployments already set
`transient_environment: true`, which excludes them from GitHub's automatic
inactivation of earlier deployments to the same environment.
No per-PR GitHub environment is created by these recording steps.

The manual build retains `plasma.oli.cmu.edu` as its job-level environment and
approval gate for reviewed fork code. The shared reporting environment does not
replace that gate.

Argo CD in `oli-torus-gitops` owns Kubernetes deployment and namespace cleanup.
A successful GitHub deployment status means the image was published; it does not
confirm application readiness. See the
[GitOps deployment guide](https://github.com/Simon-Initiative/oli-torus-gitops/blob/master/docs/handbook/deployments.md)
for runtime configuration, preview access, seeding, and namespace lifecycle.

## GitHub Setup

1. No manual environment creation is required. GitHub creates **`plasma-previews`**
   when the updated workflow first records a deployment. No secrets, variables,
   reviewers, or branch restrictions are needed for this reporting environment.
2. Keep **`plasma.oli.cmu.edu`** and its existing required reviewers for manual builds.
3. Merge the workflow change into `master`. No new token, repository secret, DNS
   entry, or cluster configuration is required.
4. Build two PR previews using the updated workflow. Verify that each PR links to
   its own URL under `plasma-previews` and both deployments remain active.

## Clean Up Legacy GitHub Environments

This change reuses a single environment; it does not add automatic retirement of
old deployment records or delete existing environments. GitHub deployment history
will continue accumulating under `plasma-previews`. Deployment statuses can be
marked `inactive` separately when previews are retired. With transient deployments,
GitHub displays that state as destroyed.

After verifying the updated workflow:

1. Let old workflow runs finish or cancel them. Update existing PR branches with
   `master` before their next preview build. Rerunning old workflow revisions may
   recreate `preview-<number>` environments.
2. Identify environments named exactly `preview-<digits>` and check each PR's
   current state. Inspect each environment for custom secrets, variables, or
   protection rules before deleting it.
3. For closed or merged PRs, delete the old environment in **Settings → Environments**.
   For open PRs, first publish through the new workflow and verify the shared
   environment's PR link, then delete the old environment.
4. Preserve `plasma-previews`, `plasma.oli.cmu.edu`, and all other environment names.

To inspect candidates without making changes:

```bash
gh api --paginate 'repos/Simon-Initiative/oli-torus/environments?per_page=100' \
  --jq '.environments[].name | select(test("^preview-[0-9]+$"))'
gh pr list --repo Simon-Initiative/oli-torus --state open --limit 1000 \
  --json number,url
```

An administrator can batch the same checks and deletions with `gh api`. Environment
deletion requires repository administration privileges and removes associated
secrets and protection rules. It does not remove Kubernetes workloads or images.
See [GitHub's environment deletion documentation](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments#deleting-an-environment).

## Smoke Testing

For preview images that include `/readyz`, pass that endpoint to the external
`devops/scripts/smoke-test-preview.sh` readiness check:

```bash
devops/scripts/smoke-test-preview.sh https://preview-123.plasma.oli.cmu.edu/readyz
```

The external script is not distributed in this repository. Before using it, verify
that it checks HTTP 200 and JSON `status: ready` without expecting Playwright-only
version/SHA fields in a preview build. It must exit nonzero on failure. Deploy an
image with `/readyz` before changing an existing readiness consumer. `/healthz`
checks startup/liveness only and no longer proves database availability. This
documentation does not migrate other deployments' Kubernetes probes.

## Seeded demo account login

Preview seeding supports an optional `PREVIEW_DEMO_USER_PASSWORD` in the runtime Secret for
new demo accounts. See [Direct QA Login](manifests/preview-seeding/README.md#direct-qa-login)
for account emails, login paths, password requirements, and the one-time seeding boundary.
The bootstrap administrator continues using its separate `ADMIN_PASSWORD`.
