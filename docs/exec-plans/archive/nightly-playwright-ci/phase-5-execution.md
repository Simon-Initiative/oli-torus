# Phase 5 Execution Record

Work item: `docs/exec-plans/current/nightly-playwright-ci`
Phase: 5 — GitOps update contract and target provisioning
Status: Complete on 2026-10-15 under the operator-approved provisioning scope.

## Scope from plan.md

Implement and validate the GitOps update contract, provision the nightly target and
integration inputs, and verify initial readiness/private asset access. The operator moved
all remaining live App, integration, persistence/mailbox, and lifecycle verification to
Phase 6 on 2026-10-15. G5 is complete; operational acceptance criteria remain unverified
until their Phase 6 checks pass.

All GitOps paths below are relative to `oli-torus-gitops`; no local checkout path is saved.

The completed provisioning procedure is in GitOps
`docs/handbook/runbooks/nightly-playwright.md`. The remaining work is listed in
`plan.md` under Phase 6's implementation, feature-branch verification, and launch checklists.

## Implementation Blocks

- [x] `scripts/update_deployment_record.py`: nightly updates require the reviewed
  enabled staging/public target and exact hostname. Only existing image/source/SHA
  scalar spans change, preserving comments and unrelated text. Reject infrastructure
  flags, ambiguous YAML, missing metadata, short/mismatched image identities, and absent
  records. Restore original content after repository validation fails.
- [x] `scripts/nightly_deployment_pr.py`: supports only `wait` and `settle`; no
  preflight or scan for previous runs' PRs. GitHub enforces the provisioned merge rules.
  Merge waiting defaults to 15 minutes, clamps API calls/polling to the
  remaining deadline, verifies exact PR/accepted-commit diffs, and rereads accepted branch
  intent. Conflicts require a newly validated PR. Cancellation/timeout gets a separate
  60-second cleanup deadline; raced merges are reconciled while failure remains nonzero.
- [x] `argocd/appsets/oli-torus-deployments.yaml`: only `nightly-playwright` receives the
  planned startup/liveness/readiness probes, 60s grace, a drain RPC killed after 5s, and
  10s propagation wait. One replica plus `Recreate` avoids overlapping mailbox instances.
  Application/setup image parity and persistent Postgres/MinIO are preserved. Other
  overlays retain their existing probe contract.
- [x] `.github/workflows/validate.yml`: test update and PR lifecycle behavior, render manifests, and run
  validation on `master`, matching the actual reconciled branch.
- [x] `docs/ci/deployment-update-workflows.md` and
  `docs/handbook/runbooks/nightly-playwright.md`: record helper usage, credential scope,
  provisioning inputs, pause/wait/manual-update ownership, stale-PR recovery, durable
  fixture preservation, and no automatic database rollback.
- [x] GitOps implementation and follow-up merged through PRs #7–#9 with passing hosted validation.
- [x] Protected branches, review/validation rulesets, App registration/installation,
  deployment credentials, and environment branch policies configured. App authentication
  and actual unattended merge remain unverified.
- [x] Target enabled with the capable published image, runtime secrets, HTTPS ingress,
  successful image pull, healthy Postgres/MinIO, bound claims, and verified probe/drain manifests.
- [x] Private adaptive assets and Dot YAML uploaded and access verified. Canvas/Moodle
  configuration and operator setup recorded; `nightly-dot` configured. Automated
  integration execution remains pending; Dot creates its test data during execution.
- [x] Torus loader/workflow follow-up `58559905f8` prepared and locally verified.
  Phase 6 must include it in the pushed feature branch; a Torus `master` merge is not
  a prerequisite for controlled verification.

The initial-image enablement change has merged and the nightly target is running.
The initial
implementation used local validation only; subsequent GitHub provisioning is recorded below.
Live access was subsequently authorized for Vault provisioning as recorded below.
Automated PR creation, signed commits,
unique-branch recovery after ambiguous creation, and helper invocation/finalization in the
Torus workflow remain Phase 6 work; the helper itself never pushes or creates a PR.

## Test Blocks

- [x] `python3 -m unittest discover -s scripts/tests -v`: 18 automation tests pass after
  removing the standalone preflight and its four tests on 2026-10-14. Coverage includes
  exact textual diffs/comments, wrong/disabled targets, rejected mutation flags, rollback
  on validator failure, conflicting/denied PRs, timeout, accepted-branch mismatch,
  cancellation routing, late merges, unexpected merged content, current-run PR ownership,
  and API deadline clamping. The previous 22-test result included the removed preflight tests.
- [x] `python3 scripts/validate_deployments.py`: four records validated.
- [x] `python3 scripts/validate_gitops_policy.py`: passes.
- [x] `python3 scripts/validate_followups.py`: passes.
- [x] Static `kubectl kustomize` checks pass for both cluster bootstrap entrypoints,
  `argocd/root`, `argocd`, and prod/staging/sandbox/preview overlays. The earlier 23-test
  run also checked the extracted nightly patch in a staging render: probes, drain hook,
  replicas/strategy, image parity, persistent volume claims, and unaffected overlays.
  That manifest test has been removed; this remains historical static evidence, not
  ongoing regression coverage or proof of ApplicationSet controller behavior.
- [x] `git diff --check` in both repositories and work-item validation pass.
- [x] Initial live readiness/identity, private asset delivery, and manual Moodle
  launch/grade-passback verification.

Remaining verification is owned by Phase 6: actual App authentication/signed merge/check
enforcement/cleanup; authenticated Canvas and automated Moodle/adaptive/Dot execution;
durable data/object survival and mailbox reset; and controlled slow boot, database
outage/recovery, and graceful termination. These checks have not passed yet. The full
feature-branch workflow and controlled operational exercises will supply the evidence.

The initial GitOps implementation changed no Elixir, shared test configuration, or browser
behavior; its verification used the GitOps tests and validators. The later parameter-loader
change is covered by the focused Playwright tests recorded below. GitOps changes were committed on
2026-10-14 as signed commit `ca02cf2` on `nightly-playwright` and pushed for
[GitOps PR #7](https://github.com/Simon-Initiative/oli-torus-gitops/pull/7) against
`master`. PR #7 merged on 2026-10-14 as
`0f6b9d0ac3751e5eb3564dae386005e6860c51a3` with a successful hosted `validate` check.
The GitOps review-and-merge checkpoint is complete; Phase 6 live verification remains open.
Disposable draft/render files are removed; retained regression tests protect the core
update and lifecycle requirements.

The preflight-removal/runbook follow-up was cherry-picked from `d81b311` to `b042a50`
on a clean branch from GitOps `origin/master`. [PR #9](https://github.com/Simon-Initiative/oli-torus-gitops/pull/9)
merged on 2026-10-15 at 14:38:15 UTC as `1fa4fcd50f6eda51fdf7b873e632dbf79c0e2548`.
Its hosted [validate check](https://github.com/Simon-Initiative/oli-torus-gitops/actions/runs/38752861342/job/116483488142)
passed. The Torus loader, environment-variable wiring, and documentation are committed
as `58559905f8`; Phase 6 will push and test it with the workflow changes before merging Torus `master`.

## Work-Item Sync

- [x] PRD, FDD, plan, and GitOps runbook distinguish completed Phase 5 provisioning from
  unresolved Phase 6 verification; no acceptance criterion is marked verified by this reorganization.
- [x] Preflight work-item validation passed; postflight validation passed.

The following notes record provisioning in execution order. Earlier pending observations
are superseded by later evidence and the current checklists above.

Read-only GitHub verification on 2026-10-14 after operator configuration:

- GitOps automatic merging and squash merging are enabled.
- Active `master` ruleset `18337042` requires the `validate` check from GitHub Actions
  (integration `15368`) and requires the branch to be up to date.
- The existing one-approval PR rule, signed commits, linear history, creation/deletion
  restrictions, and force-push protection remain effective.
- The merge-settings/required-check checkpoint is complete. App credentials, unattended
  approval, environment restrictions, and the actual bot lifecycle remain unverified.
- Organization-owned App `torus-nightly-gitops` (App ID `5319179`) is registered with
  Contents read/write, Pull requests read/write, Metadata read, and no webhook events.
  Installation `171452191` is active and uses selected repositories. Exact repository
  access will be verified with App authentication; no private key was read.
- Torus environment `nightly-deploy` permits only branch `master`, with no reviewer or
  wait gate. Variables `GITOPS_APP_ID` and `GITOPS_BOT_LOGIN` match the registered App;
  secret `GITOPS_APP_PRIVATE_KEY` exists. Only metadata was inspected, so key validity
  and authenticated access remain unverified. Build/browser jobs must not use this
  environment. The user selected a separate one-review ruleset with a pull-request-only
  App bypass, keeping required PRs, signatures, and validation in the main ruleset without
  an App bypass. The final ruleset configuration is verified below; an actual bot merge
  remains unverified. No approval workflow is planned. The user removed the second App/read-only
  credential requirement and standalone preflight; this App serves PR operations and cleanup.
- Ruleset split read back on 2026-10-14: main ruleset `18337042` requires PRs with zero
  approvals, signed commits, and up-to-date GitHub Actions `validate`, with no bypass
  actors. Review ruleset `25103794` requires one approval and includes the deployment
  App with verified bypass mode `pull_request`, matching the selected contract.
  Both rulesets target the default branch
  and are active. Automatic squash merging remains enabled; actual bot merge is unverified.
- Torus `nightly-ui` was initially restricted to branch `master`,
  with no reviewer or wait gate, matching `nightly-deploy`. Manual feature-branch
  verification requires explicitly allowing the reviewed branch in the environments
  used by that run.
- `nightly-ui` also allows the explicitly reviewed branch
  `MER-6036-phase-5-git-ops-update-contract-and-target-provisioning` for initial image
  publication. `nightly-deploy` remains restricted to `master`.
- The reviewed publish-only workflow change was committed as `9d1d117e58` and the
  feature branch was pushed. Manual [provisioning run 38613155854](https://github.com/Simon-Initiative/oli-torus/actions/runs/38613155854)
  uses source `9d1d117e589228f09e1681f6e28997f53d06c27b` and `publish_only: true`.
  Publication succeeded; both test jobs were skipped. Image version is `0.35.0`:
  - Image: `ghcr.io/simon-initiative/oli-torus:sha-9d1d117e589228f09e1681f6e28997f53d06c27b-playwright-38613155854-1`
  - Digest: `sha256:6e905eca8d0dad5651be1c0118eda5db52808c096eb7f7766654bfe772e6329a`
  - An isolated local container verified the image exports `Oli.Release.drain/0`,
    includes the `/readyz` route, and supplies `/usr/bin/timeout`. Live HTTP and drain
    behavior in the deployed image remain pending.

Read-only GitHub audit on 2026-10-13 (authentication verified outside the network sandbox):

- GitOps default/reconciled branch is `master`. It is protected by active rulesets,
  not classic branch protection. Rules require squash PR merges, one approval, signed
  commits, linear history, and restrictions on creation/deletion/non-fast-forward updates.
- No effective required status-check rule exists. Repository `allow_auto_merge` is false;
  squash merging is enabled. These were preflight gates in the original helper; that command has since been removed.
- `nightly-ui` exists with no protection rules or deployment branch policy. It currently
  permits branch selection without a configured branch allowlist. Configure trusted
  branch restrictions without adding per-run approval to unattended master execution.
- Only Canvas UI credentials and the scenario token appear as environment secret names.
  Repository secret/variable names were also inspected; values and organization-level
  inheritance were not read. These names do not establish complete runtime configuration
  or a GitOps App installation. App permissions and integration connectivity are unverified.
- The proposed operator handoff requires enabled auto-merge, strict GitHub Actions
  `validate` checks, a reviewed bot-specific approval path preserving required validation,
  signed bot commits, and a disposable end-to-end bot PR proof.

The operator authorized Vault provisioning through `eknebel@plasma.oli.cmu.edu` on
2026-10-14. Read-only checks confirmed that host uses Kubernetes context `default`,
`plasma-vault/vault-0` is running, Vault authentication works, and the nightly payload
did not yet exist. A create-only Vault write created version 1 at
`secret/data/oli-torus/deployments/nightly-playwright` on 2026-10-14 at 18:29:16 UTC,
using the operator-selected `admin@example.edu` and fresh credentials. Read-back
verified all 19 fields, database URL/password consistency, key lengths, and distinct
Playwright tokens without displaying secret values. The operator copied the credentials
into `nightly-ui`; GitHub metadata confirms updates to `TORUS_ADMIN_EMAIL`,
`TORUS_ADMIN_PASSWORD`, `PLAYWRIGHT_SCENARIO_TOKEN`, and `PLAYWRIGHT_CAPTCHA_TOKEN`
between 18:33 and 18:34 UTC. GitHub does not return secret values, so this confirms
their presence and update times, not value equality or successful authentication.
Read-back confirms both `PLAYWRIGHT_BASE_URL` and `TORUS_BASE_URL` environment variables
are `https://nightly-playwright.plasma.oli.cmu.edu`. ExternalSecret reconciliation and
private bucket creation and asset uploads subsequently succeeded as recorded below.
The automation API key is configured as recorded below; external integration setup
remains pending.

Read-only checks before enablement confirmed `vault-cluster` is Ready and the
nightly namespace did not yet exist. The default `local-path` StorageClass uses
`/var/lib/rancher/k3s/storage` on the 80 GiB `/var` disk. Available filesystem space was
17,517,584,384 bytes (about 16.3 GiB), compared with the planned 10 GiB Postgres and
10 GiB MinIO claims. The operator accepted proceeding with current capacity and will
address storage separately; this observation is not evidence that Kubernetes will
reject those claims. Host-side DNS resolves the nightly hostname to `10.0.0.41`;
an external request reached `23.21.79.144` with successful TLS verification and HTTP 404
before the nightly ingress exists. Anonymous GHCR manifest access and a local image pull
succeeded with the expected published digest, so no registry pull credential is required
for this image. Cluster image pull and application HTTPS readiness subsequently succeeded.

The initial enablement change, commit `a41a69f` on GitOps branch
`nightly-playwright-enable`, merged through [GitOps PR #8](https://github.com/Simon-Initiative/oli-torus-gitops/pull/8)
on 2026-10-14 at 18:44:30 UTC as `d19e294829efbf4f5a0b1825f51b0cbe0873ad77`.
Its hosted `validate` check passed in [run 38617265320](https://github.com/Simon-Initiative/oli-torus-gitops/actions/runs/38617265320).
It sets
`enabled: true` and the published image/source metadata in the nightly record only.
It preserves the staging overlay, public hostname, persistent services, and lifecycle
contract. An isolated snapshot of that proposed PR passed all 22 tests currently on
GitOps master, all repository validators, and five renders. The separate uncommitted
preflight-removal follow-up remains outside this enablement change; its 18-test suite
also passes. Private assets were installed after the target's services became available;
integration fixtures remain required before full-suite launch. Enablement alone does not close G5.

Live provisioning verification after merge:

- The root Argo application `oli-torus-gitops` requires manual sync. Its live deployment
  ApplicationSet lacked the reviewed lifecycle patch. A comparison confirmed that patch
  was its only spec difference. A selective sync at the accepted commit applied only
  `argocd/oli-torus-deployments`; unrelated preview resources remained outside the operation.
- The generated nightly Deployment now matches the complete probe/drain contract,
  60-second grace period, one replica, `Recreate`, and setup/application image parity.
- Both 10 GiB persistent claims are Bound; Postgres, MinIO, and the application are Ready.
  The runtime ExternalSecret reports `SecretSynced` and Ready.
- Argo reports the nightly application Synced, Healthy, and its sync operation Succeeded.
  Public HTTPS `/readyz` and `/healthz` return 200. Readiness reports version `0.35.0`
  and source `9d1d117e589228f09e1681f6e28997f53d06c27b`, matching publication.
- Created `torus-playwright-assets` through the namespace-local MinIO client. Its access
  policy reports private, and an anonymous request through the public bucket ingress
  returns 403. Temporary client configuration was removed.
- Uploaded all 15 expected objects from the operator-provided
  `adaptive_pw_tests_s3_folders.zip`: eight course archives and seven answer files,
  totaling 117,240,415 bytes. Paths match the adaptive setup guide; course ZIP and
  answer JSON integrity checks passed. macOS metadata was omitted. Each stored object
  matched its source SHA-256, byte size, and content type. Course archives and answer
  files were transferred unchanged without extracting their contents onto Plasma.
- Authenticated downloads through the public Torus `/test/assets/` endpoint verified
  a course archive and answer file against the source checksums, with HTTP 200,
  attachment disposition, and `private, no-store` caching. Anonymous requests return
  401 through Torus and 403 through the direct bucket ingress. No asset contents or
  tokens were displayed, and temporary MinIO client configuration was removed.
- The operator created the `Nightly Playwright automation` API key and saved
  `PLAYWRIGHT_AUTOMATION_API_KEY` in `nightly-ui`; GitHub metadata confirms its update
  at 18:57:21 UTC. A server-side check confirmed enabled status and automation setup
  access. Torus had defaulted payment/product scopes to true; these were switched off
  through `Oli.Interop.update_key/2`, preserving the generated key and automation access.
  Final scope flags are automation true, payments/products/registration false. No key
  or hash was displayed. End-to-end use of the GitHub-stored value remains unverified.
- This verifies initial deployment, not the outstanding controlled slow-boot,
  database-outage/recovery, drain, persistence/mailbox, bot lifecycle, or integration tests.

Canvas provisioning is in progress. The operator created a dedicated LTI developer key
using the nightly `/lti/developer_key.json` endpoint and supplied Client ID
`10000000000100`. The endpoint was verified to use the nightly launch, OIDC login,
and public JWKS URLs. The operator installed the account-level app with display name
`OLI Torus (nightly Playwright)` and Deployment ID
`186:8865aa05b4b79b64a91a86042e43af5ea8ae79eb`. The Canvas public JWKS endpoint is
reachable. The operator confirmed the issuer as `https://canvas.oli.cmu.edu`.
A read-only runtime query verified institution `Canvas Nightly Playwright` (ID 1),
with institution URL `https://canvas.oli.cmu.edu`. After the operator saved the forms,
a second query verified registration ID 1 with the confirmed issuer/client ID and
Canvas JWKS, authorization, token, and auth-server URLs. Deployment ID 1 contains
the supplied Canvas deployment ID and links registration 1 to institution 1.
Canvas authenticated launch verification remains pending.
The operator confirmed Canvas account ID `1` and identified instructor user ID `2676`.
GitHub environment metadata verifies `CANVAS_ACCOUNT_ID=1`,
`CANVAS_INSTRUCTOR_USER_ID=2676`, the Canvas base URL, the nightly tool display name,
and the nightly launch URL. `CANVAS_UI_EMAIL` and `CANVAS_UI_PASSWORD` were updated,
and `CANVAS_API_TOKEN` was saved at `2026-10-14T20:09:54Z`. Secret values were not read;
login validity and API permissions remain unverified until authenticated execution.
Phase 6 must pass the additional Canvas variables and API secret into the browser job.
The current Canvas `@nightly` launch
test needs an instructor login; the separate Canvas grade-passback test uses student
and instructor logins but is not tagged `@nightly`.
Canvas's public OpenID discovery endpoint returned 404; the issuer confirmation came
from the operator.

Moodle provisioning is in progress. The operator confirmed site-administration access
to `https://oli.moodlecloud.com` and supplied configuration details for the new nightly
LTI 1.3 tool:

- Platform ID: `https://oli.moodlecloud.com`
- Client ID: `cRgGhEwmWpnyUnH`
- Deployment ID: `7`
- Public keyset URL: `https://oli.moodlecloud.com/mod/lti/certs.php`
- Access token URL: `https://oli.moodlecloud.com/mod/lti/token.php`
- Authentication request URL: `https://oli.moodlecloud.com/mod/lti/auth.php`

The requested tool name is `OLI Torus (nightly Playwright)`, with nightly Torus launch,
login, and JWKS URLs. The operator authorized dedicating the two existing Moodle
fixture courses to nightly Torus; their activity tool selections must be updated.
A read-only runtime query verified institution `Moodle Nightly Playwright` (ID 2),
registration ID 2 with the supplied issuer/client ID and endpoints, and auth-server
URL `https://oli.moodlecloud.com/`. Deployment record ID 2 contains Moodle deployment
ID `7` and links registration 2 to institution 2. This verifies stored configuration;
authenticated launches, test users, API access, and nightly course fixtures remain
unverified. The Moodle credential secrets named `MOODLE_INSTRUCTOR_EMAIL` and
`MOODLE_STUDENT_EMAIL` must contain Moodle usernames: the current helpers use them
for both browser login and API username lookup.
GitHub metadata verifies all four Moodle login secrets were saved on 2026-10-14,
along with `MOODLE_BASE_URL=https://oli.moodlecloud.com` and
`MOODLE_LTI_TOOL_NAME=OLI Torus (nightly Playwright)`. Secret values and successful
logins have not been independently verified. GitHub metadata now verifies
`MOODLE_API_TOKEN` in `nightly-ui`, saved at `2026-10-14T20:35:22Z`.
The current API helper uses six functions: course lookup, creation,
deletion and import, user lookup, and manual enrollment. The historical setup guide
also lists category lookup and module deletion, which the current helper does not call.
The operator confirmed the Moodle web-service setup is ready after instructions to
enable web services and REST and configure the restricted `Torus Playwright Automation`
service with the six required functions. The operator saved the API token in GitHub
after an initial destination check found it missing. Provisioning user authorization
and API access have not been independently verified. Next, provision the Torus project
and Moodle course fixtures. The existing fixed-shortname courses have been inspected
and authorized for conversion from Tokamak to nightly Torus.

The operator created project `PLAYWRIGHT_MOODLE_LTI_TEST` at
`https://nightly-playwright.plasma.oli.cmu.edu/workspaces/course_author/playwright_moodle_lti_test/overview`.
A read-only runtime query verified project ID 2, Open (`global`) visibility, and
publication ID 2 published at `2026-10-14T20:37:33Z`. Its graded page is titled
`Graded page for graded passback` and references exactly two activities. The
multiple-choice activity awards 1 point for `Choice A` and 0 for `Choice B`; the
text activity awards 1 point for input containing `answer` and 0 otherwise. These
rules match the test inputs (`answer` and `incorrect`) and expected 2-point total.
Moodle course links and end-to-end grade passback remain unverified.
The operator confirmed that existing Moodle courses with shortnames
`playwright_moodle_lti_template` and `playwright_moodle_grade_passback` both use the
Tokamak external tool. These shortnames are currently hardcoded in the tests.
The operator explicitly authorized dedicating both fixtures to nightly Torus. Keep
their existing shortnames and update each external-tool activity to the nightly tool,
with activity name `OLI Torus (nightly Playwright)`. No duplicate courses or configurable
course names are needed. Enroll the configured nightly instructor/student in the
grade-passback course and complete its first nightly launch to create the persistent
Torus section. The operator created new nightly-tool activity instances instead of
editing the existing instances, then supplied section URL
`https://nightly-playwright.plasma.oli.cmu.edu/sections/moodle_grade_passback_fixture_/manage`.
A read-only query verified section ID 1, Moodle context ID `74`, institution ID 2,
deployment record ID 2, and base project ID 2. This confirms the instructor launch
created the section through the intended Moodle registration. Template activity
contents, old-activity removal, and student enrollment remain independently unverified.

The section check exposed a curriculum issue: the published project contains the graded
page, but its root revision has an empty `children` list. The working publication has
the same empty hierarchy. Consequently, the section has no graded-page resource.
The earlier publication check verified question content and scoring but missed this
hierarchy requirement. After the operator moved the page into the curriculum and
republished, a read-only query verified publication ID 3 at `2026-10-14T20:57:50Z`,
with root `children=[3]`. Section ID 1 already uses publication 3 and now includes
the graded page (section-resource ID 4). The operator then updated its assessment
settings. A read-only query verified Most Recent scoring and `max_attempts=0`
(unlimited), with section publication ID 3. Manual grade-passback evidence is recorded
below; automated Playwright execution remains pending.

The first manual student attempt scored 2/2 at `2026-10-14T21:07:51Z`.
A read-only query verified successful LMS grade update ID 1 at
`2026-10-14T21:07:54Z`, and the section's line-items endpoint targets Moodle course
74 and tool type 7. The operator's Moodle gradebook shows two identically titled
`Graded page for graded passback` columns, at 50% and 100%, with a 75% course total.
The 100% value matches the nightly attempt; the other column likely belongs to the
previous Tokamak fixture, but its ownership has not been independently verified.
The operator then submitted the lower-scoring attempt and observed the nightly column
change from 100% to 50%. A read-only query verified the current score is 1/2 and
successful LMS grade update ID 2 at `2026-10-14T21:12:50Z`. This demonstrates manual
student launch, grading, and passback of a lower latest score. Rename the obsolete
left-hand grade item to `Archived Tokamak score` before accepting automated execution:
the test selects
the first gradebook column containing the graded-page title, so duplicate titles
could cause it to read the stale value. The operator chose to delete the obsolete
left-hand Tokamak grade item and confirmed completion. The current nightly activity
and its grade item were to be retained; this cleanup is operator-reported, not
independently verified through Moodle's API. Dot configuration is next.
Read-only Dot configuration inspection found only registered model ID 1 (`null`,
provider `null`) and service configurations `standard-no-backup` and
`instructor-email-default`, both using that placeholder. No API-key fields were
selected or displayed. The model and service setup below supplies the Dot test;
its private parameter document was uploaded as recorded below.
The operator supplied the working Tokamak model configuration: name `gpt-5`, provider
`OpenAI Compliant`, model `gpt-5`, URL template `https://api.openai.com`. On 2026-10-15,
the operator reported that the nightly admin UI's Test Model action succeeded.
A read-only metadata query verified registered model ID 2 with those settings;
the operator then saved service `nightly-dot`. A read-only query verified service
ID 3 uses `gpt-5` (model ID 2) as its primary, with no secondary or backup model.
Torus's provider
appends `/v1/chat/completions` to the base URL. No provider credential was shared in
chat or selected by the verification query. A successful streamed Dot response from
the test section remains unverified.

On 2026-10-15, the operator directed that the Playwright run test the Dot configuration
instead of a separate provisioning/verification exercise. Use the test's existing
scenario mode to create its run-specific course and student and verify the response.
The interrupted setup performed only source reads and metadata queries; no Dot
project, section, student, or Vault credential was created. The private parameter
document must select scenario mode, the nightly target/token, and `nightly-dot`.
The existing scenario has no automatic teardown; retain operator cleanup between
runs as documented in the FDD, without adding cleanup infrastructure here.

On 2026-10-15, uploaded `dot_chatbot/config.yaml` to the existing private
`torus-playwright-assets` bucket. The YAML selects scenario mode, the nightly origin,
the deployment's scenario token, `nightly-dot`, a generated test password, and
`${RUN_ID}` course/student identities. Credentials were generated or read in server
memory; no secret-bearing local file was created. No Dot scenario was executed.
Authenticated download through `/test/assets/dot_chatbot/config.yaml` returned 200
and matched the uploaded 814-byte object's SHA-256
`260a2fb7595d2f6c1bd59f64b4c55e53684fc315fdee8a92849ca357d182a614`.
The response used `Cache-Control: private, no-store`; anonymous access returned 401,
and direct bucket ingress access returned 403.

The parameter loader now authenticates same-origin `/test/assets/` downloads with
the runner's scenario token and refuses redirects for those requests. External URLs
retain unauthenticated downloads. Request and YAML parsing errors omit credential-bearing
details. All 12 focused configuration-loader tests pass, including real HTTP authentication
and redirect rejection. The operator reported saving the download URL as the GitHub
`nightly-ui` environment variable `PLAYWRIGHT_PARAMETER_CONFIG_URL` on 2026-10-15.
The workflow now reads `vars.PLAYWRIGHT_PARAMETER_CONFIG_URL`; the URL contains no
credentials, and authentication continues to use the separate scenario-token secret.
The workflow and loader changes must be included in the runner checkout before using
this URL. Dot response verification remains part of the Playwright run.

## Review Loop

- The configuration URL's switch from `secrets` to `vars` passed security and
  performance review, diff checks, and work-item validation. Actionlint reports only
  the same pre-existing `actions/cache@v3` warning found in the committed workflow.
- The private Dot configuration loader passed all 12 focused Playwright tests,
  ESLint, formatting, diff checks, and work-item validation. Security, performance,
  and TypeScript reviewers found no issues. Authenticated asset delivery was verified
  live; the Dot scenario and model response remain for the Playwright run.
- The publish-only workflow change passed security and performance review, YAML/default
  and job-gate checks, and work-item validation. Build/test job bodies, schedule, and
  concurrency are unchanged. Actionlint reports the same pre-existing `actions/cache@v3`
  warning in the scenario job on both the baseline and changed workflow; that job is
  skipped for provisioning. Hosted publication succeeded with both test jobs skipped.
- After preflight removal, security, performance, and requirements reviews found no
  issues in the simplification. All 18 remaining tests, CLI argument checks, repository
  validators, required renders, and work-item/requirements validation pass. This
  follow-up was committed as `d81b311` on 2026-10-15 and landed through PR #9 as
  `1fa4fcd`. Before committing,
  all 18 tests, three repository validators, and eight static renders passed again.
  The runbook's scenario-mode Dot setup also passed security and performance review.
- Required harness-review security and performance reviewers inspected the GitOps diff.
- The original security review fixed a prefix-spoofing denial of service in preflight.
  The user subsequently removed that command and its tests. Current-run ownership checks
  remain; previous-run PR discovery is no longer part of the contract.
- Performance/reliability review found no blocking findings; its suggested cancellation
  entry-point coverage was added. API/polling/cleanup bounds are tested.
- Required checks and merge settings remain provisioning requirements enforced by
  GitHub; the helper no longer audits them before every deployment.

## Done Definition

- [x] All Phase 5 provisioning tasks complete; G5 closed under the approved scope.
- [x] Local tests and static verification pass.
- [x] Required review completed and findings resolved.
- [x] Work-item validation passes.

Phase 6 integrates and verifies the complete workflow on an explicitly allowed feature
branch. Unattended launch remains gated on its actual App, integration, lifecycle,
persistence, failure-handling, and artifact checks, followed by a scheduled run after merge.

## Decision Log

- 2026-10-15: Operator moved every remaining Phase 5 live check to Phase 6 and approved
  closing G5 on completed provisioning. This supersedes the earlier same-day open-G5
  decision below. The Torus loader follow-up is tested from the feature branch rather
  than requiring a prior master merge. No missing proof is marked passed; Phase 6 owns
  feature-branch, operational, and scheduled launch verification.
- 2026-10-15: Split completed provisioning from unverified operation in the Phase 5
  checklist. PR #9's merge/check evidence and the recorded target, asset, and integration
  setup support the completed items; no live test or acceptance criterion is promoted
  without proof. G5 remains open.
- 2026-10-15: Retain the existing Torus `/test/assets/*path` route for the Dot YAML
  download, as accepted by the operator after clarifying that it retrieves the single
  MinIO object. Keep the configured URL and scenario-token authentication; direct
  MinIO authentication and additional runner credentials are unnecessary.
- 2026-10-14: Add a manual `publish_only` workflow input for initial provisioning from
  the reviewed feature branch. It defaults to false and skips both test jobs only when
  explicitly selected on manual dispatch. Publication records image provenance without
  running tests against an unprovisioned target. Phase 6 must also skip deployment for
  this mode; normal scheduled/manual execution remains unchanged.
- 2026-10-14: Use a separate review ruleset with an App bypass for pull requests only.
  Keep mandatory PRs (zero approvals), signed commits, and required checks in the main
  ruleset without an App bypass. The exception covers any PR the App merges; the helper
  restricts automated updates to the nightly record. No approval workflow is needed.
- 2026-10-14: User removed standalone GitOps preflight and checks for prior bot PRs,
  superseding the intermediate proposal to move preflight into deployment. Keep one
  App in `nightly-deploy`, current-record validation, merge verification, and current-run
  cleanup. Operators handle orphaned PRs; later runs do not detect or reject them.
- 2026-10-14: Remove `scripts/tests/test_nightly_manifests.py` because its exact-value
  assertions largely duplicate manifest configuration. The then-current suite retained 22 automation tests,
  CI renders, and repository validators. Live lifecycle verification remains required.
- 2026-10-14: Phase 6 now includes launch verification formerly assigned to Phase 7.
  Reuse this record's valid evidence; G5 still requires the outstanding live checks.
  The plan separates completed local helper/manifests from provisioning. Its early
  build-preflight credential proposal was superseded by the one-App decision above.
  Moodle is included because its existing tests are tagged `@nightly`.
