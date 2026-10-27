# Phase 3 Execution Record

Work item: `docs/exec-plans/current/nightly-playwright-ci`
Phase: `3 — Release packaging and build isolation`

## Scope from plan.md

- Docker context/build isolation, compiled identity and OCI metadata.
- Public runtime fixtures, runtime-only credentials and isolated release smoke checks.
- No registry publication or GitOps mutation performed. Native build job added to the nightly workflow after the user scope correction; Plasma deployment/readiness and full orchestration remain Phase 6.

## Implementation Blocks

- [x] `Dockerfile` retains the production default, requires a full SHA for Playwright, separates build scopes and produces the release image with standard Mix/Docker steps. OCI labels record source, revision and supplied version. Configuration precedes dependency compilation; source precedes application compilation; host build outputs never enter the context.
- [x] `.dockerignore` now allowlists build inputs and excludes automation, nested dependencies, generated assets/reports, local secrets/certificates and host caches. A synthetic-canary context export verified those exclusions and the required fixture inclusions (the verifier inclusion was removed in the follow-up below).
- [x] Moved the three established public support endpoint fixtures to `priv/playwright`. The controller uses `Application.app_dir/2`; symlinks retain existing local paths. No private archives, preview seed modules or `test/support` modules were added to Playwright compilation.
- [x] The `build-playwright` job in `.github/workflows/nightly-playwright.yml` implements scheduled/manual packaging with ordinary build-info, Docker metadata, login and build/push steps modeled on `package.yml`. It uses full-SHA/run/attempt tags, pushes directly with normal registry behavior and records the published digest. Actions use explicit version tags; scheduled execution selects master, manual execution selects the dispatch SHA, and both use the target lock. The workflow has not been dispatched.
- [x] Local release verification used isolated PostgreSQL/MinIO services and generated runtime-only secrets. The temporary smoke harness and metadata CLI, including their four unit tests, were removed after the user requested the simpler `package.yml` workflow pattern. Their completed runtime evidence below remains historical verification, not a maintained operational tool.
- [x] The FDD and runtime release notes below record ExAws/bucket/service inputs, normal release setup, fixture audit, mailbox reset and the one-replica requirement for Phase 5.

## Test Blocks

- [x] Focused backend verification: **28 tests, 0 failures**. Covered public support assets (including PNG signature), shared configuration, captcha, readiness and mailbox authorization/filtering. No shared test configuration or test setup logic changed. Test bodies produced normal ExUnit progress and summary; the runtime emitted its existing OS-monitor shutdown messages after the summary.
- [x] Historical helper checks: **4 tests passed** before the Python tooling was removed. Current workflow verification uses actionlint and direct shell-step checks.
- [x] Clean Playwright and production Docker builds passed on `linux/amd64`; each selected its own compile environment/scope. Both independent cached builds also passed, reusing their respective dependency/application/release layers.
- [x] An isolated temporary source copy with changed Playwright compile configuration and source rebuilt dependency/application/release layers successfully. The changed configuration appeared in its assembled release and remained absent from the original image; the working tree was not mutated for this check.
- [x] Actual assembled `sys.config` accepted the correct version/SHA and rejected incorrect SHA/version expectations. OCI metadata and image history passed the harness checks. Both final images were saved and every filesystem layer inspected (16,176 entries each), with no excluded source trees, local secret files or canaries found. No runtime secrets were passed to the builds.
- [x] Complete two-image release smoke matrix passed. Playwright returned compiled version/full SHA in ready and draining responses, including after runtime build changes. Production returned status only in both states and kept scenario/mailbox/support/private-asset routes excluded after runtime capability overrides. Captcha selection remained immutable in both builds; production retained its normal verifier.
- [x] Playwright served all three packaged public fixtures without source-tree mounts; authenticated scenario execution and synthetic private-object retrieval succeeded. Missing/wrong authorization was rejected. Missing scenario/captcha startup tokens failed closed.
- [x] Local mail capture, recipient/subject filtering and message-ID retrieval passed. Restart produced an empty mailbox while the synthetic user and object remained. Readiness recovered and draining preserved liveness.
- [x] Security, performance and Elixir reviews completed with no actionable findings; a final security follow-up also found none.

## Commands and Evidence

Builds used source HEAD `457e630b35d5a4c3f29582bf965fcebda46d1a97`, version `0.35.0`, and the local uncommitted Phase 3 implementation. These are local validation artifacts, not published source snapshots.

```sh
docker build --platform linux/amd64 --build-arg MIX_ENV=playwright \
  --build-arg BUILD_SCOPE=nightly-playwright --build-arg SHA="$SOURCE_SHA" \
  --build-arg APP_VERSION=0.35.0 -t torus-playwright-smoke .
docker build --platform linux/amd64 --build-arg MIX_ENV=prod \
  --build-arg BUILD_SCOPE=production --build-arg SHA="$SOURCE_SHA" \
  --build-arg APP_VERSION=0.35.0 -t torus-production-smoke .
```

Backend checks used a task-owned disposable database, `ERL_FLAGS="+S 4:4"`, and:

```sh
mix test test/oli_web/controllers/playwright_support_asset_controller_test.exs \
  test/oli/playwright/config_test.exs test/oli/playwright/recaptcha_test.exs \
  test/oli_web/controllers/api/readiness_controller_test.exs
mix test test/oli_web/controllers/playwright_mailbox_controller_test.exs
mix format --check-formatted lib/oli_web/controllers/playwright_support_asset_controller.ex \
  test/oli_web/controllers/playwright_support_asset_controller_test.exs
```

Two initial smoke attempts identified harness assumptions: default long Erlang node names reject a disposable container's short hostname for RPC, and Docker can reassign the published host port after restart. The successful local verification used `RELEASE_DISTRIBUTION=sname` and refreshed the port after restart. The complete matrix passed after those fixes; no application bypass or weakened assertion was introduced.

## Work-Item Sync

- [x] Plan and FDD synchronized with packaging paths, helper interfaces and evidence.
- [x] Requirements remain proposed; final operational proof belongs to later phases.
- The tag audit found newer nightly cases for Moodle, instructor and account flows. Phase 4 must cover their inputs and origins under tag-based selection; they are not silently excluded. Selected tags currently do not request the public support fixtures directly; packaging preserves those existing endpoint contracts.

## Review Loop

- Round 1: security, performance and Elixir reviewers reported no actionable findings.
- Follow-up security review: no findings after runtime override checks, restart handling and cleanup ownership hardening.

## Workflow Simplification

The user requested a direct GitHub Actions implementation modeled on
`.github/workflows/package.yml`. Removed the Phase 3 Python metadata CLI, Docker
smoke harness and their tests. The user then requested packaging as a dependency
job in the existing nightly workflow, with Plasma deployment to follow there.
Moved the native build steps into `build-playwright`, exposed source/version/image
outputs, and made the browser job depend on the build and check out its source SHA.
Removed the separate packaging workflow. Phase 6 will insert `deploy-plasma` with
GitOps acceptance and public readiness before browser execution. Until that lands,
browser tests continue targeting the existing configured server; publication alone
does not deploy the image.

Moved the target lock to workflow scope so it spans job boundaries. The scenario
job body and triggers remain unchanged; it has no build dependency, but overlapping
workflow runs now share the queue. This supersedes the earlier design's requirement
for scenario runs to remain outside the target lock. Production packaging is
unchanged. The Elixir assembled-release verifier was retained at that point and subsequently removed at the user's request (see follow-up below).
No application or Docker build behavior changed in this follow-up.

## Remaining Operational Gates

- G2 hosted PR checks remain a prerequisite before landing the earlier migration.
- Phase 5 verified one replica and provisioned persistent services. Phase 6 verifies working drain RPC/node naming and persistence/mailbox behavior through actual deployment updates.
- Real archives/answer keys and Canvas/Moodle/Dot fixtures require later target provisioning and full-suite launch evidence. Synthetic storage smoke proves packaged transport/authentication and persistence, not external course/integration correctness.
- Task-created database/services/networks and temporary context/invalidation images were removed; `torus-playwright-smoke` and `torus-production-smoke` remain available locally for inspection.
- No Jira, registry or GitOps writes, live deployment changes or live integration calls occurred.

## Done Definition

- [x] Phase implementation complete.
- [x] Final build/test verification recorded.
- [x] Review completed.
- [x] Original postflight validation, Elixir formatting and `git diff --check` passed.
- [x] Historical workflow simplification passed actionlint, build-info shell checks, tag collision/missing/auth/network checks (the collision-check step was subsequently removed at user request), work-item validation and `git diff --check`. Security and performance follow-up reviews found no actionable issues. An actual read-only GHCR lookup confirmed Docker returns `manifest unknown` for a missing tag; the former preflight step recognized that response and the CLI variant `no such manifest`. The workflow has not been dispatched; hosted publication remains unverified.

- [x] Nightly job integration verified source/image outputs, browser dependency and exact-SHA checkout, unchanged trigger definitions, unchanged backend scenario job and unchanged remaining browser steps. Build-info shell execution passed. Actionlint found only the existing scenario job's unsupported `actions/cache@v3`, reproduced against `HEAD`; lint passed with that single baseline diagnostic excluded. Work-item validation and `git diff --check` passed. Security and performance follow-up reviews found no actionable issues. No hosted workflow was dispatched.

## Manual Branch Dispatch Follow-up

The user approved manual runs against a selected branch. Removed the master-only
build guard. Scheduled builds still resolve current master after acquiring the
workflow lock; manual builds check out the exact `github.sha` selected at dispatch,
including when rerun. A new dispatch selects the branch again. Source ref is now
recorded in build outputs and the summary, alongside the source SHA already used
by browser checkout and the future Plasma deployment job.

Updated PRD, AC-002 in `requirements.yml`, FDD, plan and packaging README. They
explicitly retain the shared Plasma target/lock and require provisioning to verify
`nightly-ui` permits intended trusted repository branches. No remote environment
rules were changed. GitOps destination branch protection remains independent of
the application source branch. Deployment/readiness integration remains Phase 6.

Validation: actionlint passed excluding the previously confirmed baseline
`actions/cache@v3` diagnostic. Structural checks verified manual dispatch-SHA and
scheduled master selection, downstream SHA checkout, unchanged triggers/scenario
job and shared concurrency. Direct build-info shell checks preserved both master
and feature-branch refs with correct SHA/image tags. Work-item validation,
requirements plan/master validation, all 42 nested acceptance-criteria references
and `git diff --check` passed. Security and performance reviews found no actionable
issues. Requirements review found a stale single-job alternative in the FDD; it
was corrected to reject separate job-level locks, consistent with the approved
workflow-level lock. No hosted workflow was dispatched.

## Direct Image Push Follow-up

Removed the existing-image-tag rejection step at the user's request. The workflow
now proceeds directly from registry login to Docker build/push, preserving unique
SHA/run/attempt tags and the published digest. Updated AC-007, FDD, plan and README
to describe normal registry overwrite behavior without enforced tag immutability.
Historical collision-check evidence above refers to the removed implementation.

Actionlint passed with only the previously confirmed baseline cache-action
diagnostic excluded. Work-item and requirements plan/master validation plus
`git diff --check` passed. Security and performance reviews found no actionable
issues. No hosted workflow or registry write was performed.

## Action Version Tags Follow-up

Replaced all six action SHA references in the nightly workflow with their existing
major-version labels at the user's request: checkout v5, Buildx v3, metadata v5,
login v3 and build/push v6. Updated FDD and plan to require explicit version tags.
Actionlint passed excluding the previously confirmed baseline cache-action
diagnostic; work-item validation and `git diff --check` passed. Security and
performance reviews found no actionable issues. No hosted workflow was dispatched.

## Runtime Release Notes

Runtime inputs include database URL/name, `SECRET_KEY_BASE`, `LIVE_VIEW_SALT`,
`CLOAK_VAULT_KEY`, endpoint host/ports, media/xAPI/blob buckets and media URL, plus
separate scenario and captcha tokens. Nightly supplies `PLAYWRIGHT_ASSETS_BUCKET`
and ExAws credentials (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` or existing
`AWS_S3_*` equivalents), region and any service host/scheme/port overrides.
`config/runtime.exs` remains the canonical configuration. Supply secrets only at
runtime, never as build arguments.

`Oli.Release.setup()` creates the database if absent and runs migrations and normal
seeds; do not reset the durable database or object storage. Short local Docker
hostnames required `RELEASE_DISTRIBUTION=sname` for RPC during smoke checks; Phase 6
must verify deployment node naming and drain RPC. The instance-local mailbox
requires one application replica and starts empty after each restart. Durable
fixtures remain in the database/object storage. No mailbox cleanup job or automatic
migration rollback is introduced.

## Release Verifier Removal

Removed the custom release verifier and the entire `scripts/ci` directory at the
user's request. Removed its Dockerfile COPY/RUN steps, unused builder-stage
`APP_VERSION` argument and Docker-context exception. The final-stage version label
and workflow build inputs remain. Runtime notes now live in this record; FDD and
plan use native workflow steps rather than planning to recreate that directory.
Earlier assembled-release assertions remain historical local smoke evidence, not
a maintained build-time gate. No runtime tests or application behavior changed.

Final precommit checks passed: verifier directory/build-reference removal, byte-for-byte
fixture preservation and compatibility symlinks, all 42 acceptance-criteria
references, work-item and plan/master validation, and `git diff --check`. Workflow
lint passed with the previously confirmed existing scenario cache-action diagnostic
excluded. The earlier 28 focused tests and release smoke checks cover unchanged
application behavior; Docker images were not rebuilt after removing the verifier.
Security and performance review of the removal found no unintended issues.

## Runner Cache Review Fix

Moved final-stage `SHA`/`APP_VERSION` arguments and OCI labels below every runner
setup `RUN`, immediately before copying the release. Source identity changes no
longer invalidate package installation, Goose installation, locale generation or
application-directory ownership setup.

Verified with two actual Linux/amd64 builds of the Dockerfile's runner stage,
omitting only the application release copy. Changed both SHA and version on the
second build: all four setup `RUN` steps were cached, filesystem layers were
identical, and both images carried their respective expected revision/version
labels. The two disposable probe images were removed. This check isolates runner
caching; it does not repeat the full application build or runtime smoke matrix.
Security and performance follow-up reviews found no remaining issues.

## Decision Log

- 2026-10-15: Move the remaining deployed drain/node-naming and persistence/mailbox
  verification to Phase 6 under the operator-approved provisioning closeout. Preserve
  all existing release smoke evidence and the final operational acceptance criteria.
