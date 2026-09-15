# Phase 5 Execution Record

Work item: `docs/exec-plans/current/features/preview-environment-tooling`
Phase: `5`

## Scope from plan.md

- Design and bundle the “Getting Started with OLI Torus” course scenario.
- Add public deployment-manifest examples for one-time preview seeding.
- Add scenario, registry, manifest-contract, and Playwright-independence coverage.
- Record the already prepared private GitOps integration without copying its private configuration
  into this repository.

## Implementation Blocks

- [x] Core behavior changes
  - Added and registered `priv/preview_qa_tools/scenarios/oli_torus_getting_started_course.yaml`.
  - The scenario creates, publishes, and delivers the designed course before enrolling 12 synthetic
    learners and running fixed-profile fast progress simulation.
- [x] Data or interface changes
  - Added the public Job/Kustomize/Argo CD contract under `docs/manifests/preview-seeding/`.
  - Prepared the matching private overlay and ApplicationSet changes on the requested separate,
    uncommitted `oli-torus-gitops` branch; no private values are copied here.
- [x] Access-control or safety checks
  - The Job uses the preview-only release command without a runtime feature flag, uses direct argv,
    has zero retries, and documents fresh/reset-data recovery after partial mutation.
- [x] Observability or operational updates when needed
  - Added Job observation, one-run retention, Argo CD ordering, recovery, dev/release commands,
    paced-mode guidance, and Playwright-independence documentation.

## Test Blocks

- [x] Tests added or updated
  - Added full scenario integration coverage and public manifest/Playwright-independence contract
    coverage; updated preview configuration terminology.
- [ ] Required verification commands run
  - Automated commands pass. Fresh-database UI smoke tests, release `bin/seed` execution alongside
    a server, the Playwright deployment suite, and a disposable Argo CD lifecycle remain hybrid
    checks requiring a running environment.
- [x] Results captured
  - Final consolidated focused suite (course scenario, manifest contract, preview configuration, and
    seeding CLI): 32 tests, 0 failures.
  - `kubectl kustomize docs/manifests/preview-seeding`: rendered successfully.
  - `MIX_ENV=preview mix release --overwrite`: built successfully and packaged `bin/seed`, the
    scenario YAML, and matching registry digest.
  - Follow-up activation-boundary suite: 39 tests, 0 failures. Both development
    `mix seed scenarios list` and a rebuilt preview release's `bin/seed scenarios list` executed
    successfully with `PREVIEW_QA_TOOLS_ENABLED` explicitly unset, confirming that the flag governs
    only web-accessible QA features.
  - Harness work-item validation and `git diff --check`: passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed
  - No new unresolved design question was introduced during Phase 5 implementation.

## Review Loop

- Round 1 findings:
  - Security review recommended disabling the unnecessary service-account token mount and making
    the retained pod-template tradeoff explicit.
  - Requirements review found unrelated activities were reusing project-specific hints and that
    the structural/objective assertion coverage could pass if all YAML assertions disappeared.
  - Requirements review also confirmed that a live Playwright fixture run remains outstanding.
  - No performance or Elixir/backend findings were reported.
- Round 1 fixes:
  - Added `automountServiceAccountToken: false` with manifest coverage.
  - Documented that image, runtime-reference, or pod-security changes require recreating the
    ephemeral preview namespace so a corrected one-time Job is created.
  - Replaced the shared hint anchor with context-appropriate three-stage hints for every activity
    and multi-input part, and asserted the exact 11 structure/objective verification results.
  - Extended the Playwright independence contract test to reject startup-status dependencies.
  - Retained the deliberate absence of a global seed timeout and use of the application's runtime
    Secret, as required by the approved Phase 5 runtime/recovery contract.
- Round 2 findings:
  - Requirements review reported no remaining findings.
  - Security review found the token-mount assertion would also pass if the field were absent.
- Round 2 fixes:
  - Changed the manifest assertion to require explicit `automountServiceAccountToken: false`.

## Done Definition

- [x] Phase tasks complete
- [ ] Tests and verification pass
  - Automated verification passes; the explicitly hybrid environment checks remain open in the
    Phase 5 testing tasks and gate.
- [x] Review completed when enabled
- [x] Validation passes
