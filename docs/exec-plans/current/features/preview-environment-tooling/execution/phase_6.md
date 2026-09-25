# Phase 6 Execution Record

Work item: `docs/exec-plans/current/features/preview-environment-tooling`
Phase: 6 — Add Protected Mailbox Access

## Scope from plan.md

- Deliver preview-only, runtime-gated mailbox access without a Torus login or role requirement.
- Use deployment GitHub OAuth proxy authorization for the full mailbox subtree, preserve application identity, and retain local email containment.
- Enable web QA tools in the GitOps preview overlay. Masquerade still requires application administrator authorization and needs no mailbox-specific actor exception.

## Implementation Blocks

- [x] `lib/oli_web/router.ex` compiles a single `/dev/mailbox` forward behind `:browser` and a router-local preview mailbox pipeline. The old dev/test forward is removed; token-protected Playwright endpoints remain unchanged.
- [x] The router-local `require_preview_qa_tools/2` function requires the immutable preview build and runtime `PREVIEW_QA_TOOLS_ENABLED`, with no application authentication or role checks. It leaves `current_user` unchanged and returns generic 404 responses while disabled.
- [x] Reused `Oli.Plugs.NoCache` and retained CSRF and standard browser security headers. Removed the dedicated mailbox plug and custom CSP/nonce policy at user direction; the trusted synthetic preview mailbox uses normal Swoosh rendering.
- [x] Added no mailbox content logging or telemetry events. Existing framework request timing instrumentation remains unchanged.
- [x] In `oli-torus-gitops`, the preview runtime ConfigMap sets `PREVIEW_QA_TOOLS_ENABLED: "true"`, and the existing flag policy assertion now requires that value. Existing OAuth middleware and deployment topology remain unchanged.
- [x] Updated Torus build guidance and GitOps deployment guidance for the proxy-owned mailbox audience and separate masquerade authorization.

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Verification:

- Before test simplification, the broader mailbox/configuration, Playwright mailbox, and author/user authentication regression run passed with 79 tests.
- After removing source-string build policy tests and simplifying mailbox coverage at user direction: `mix test test/oli/preview_qa_tools/config_test.exs test/oli_web/preview_mailbox_test.exs` — 10 tests, 0 failures; clean ExUnit progress and summary. Existing seed/migration setup output occurs before ExUnit.
- Current mailbox coverage: unauthenticated viewer/JSON access in preview with QA tools enabled; 404 responses with the flag disabled or unset; absent routes outside preview regardless of the flag. Removed Torus accounts, roles, tokens, and unrelated mailbox behavior tests at user direction. Configuration tests retain strict flag parsing and local email containment coverage.
- Tests compile isolated copies of the real configuration and router with the preview marker, leaving the normal test artifact non-preview.
- `MIX_ENV=preview mix compile` — passed.
- Compiled-preview route inspection verifies exactly one mailbox forward behind the browser and preview-mailbox pipelines; route tests verify enabled access without a Torus identity and disabled rejection.
- `mix format --check-formatted` on changed Elixir files and `git diff --check` — passed.
- GitOps render checks: `kubectl kustomize` for `clusters/initial/bootstrap`, `clusters/aws-managed/bootstrap`, `argocd/root`, `argocd`, and `apps/oli-torus/overlays/preview` — passed. Checked the rendered preview ConfigMap value and ingress/service boundary.
- GitOps validation: `python3 scripts/validate_deployments.py`, `python3 scripts/validate_gitops_policy.py`, and `python3 scripts/validate_followups.py` — passed.
- The GitOps diff was reduced to the preview flag, its existing policy assertion, and deployment guidance. Extra ingress/service assertions were removed, and the accidental move of `argocd/root/` was reversed.
- Harness requirements `master_validate --stage plan_present` and work-item `--check all` — passed.

## Work-Item Sync

- [x] Updated FR-010 and AC-021/AC-026, PRD, FDD, plan, follow-on note, and operator docs for the approved 2026-09-24 contract.
- [x] Removed mailbox-specific actor authorization from Phase 7 and marked the earlier admin-mailbox decision superseded.
- AC-025 local email containment and the application access-gate portion of AC-026 have automated evidence. The non-preview mailbox test uses the normal test artifact, not a production release. Review confirms no mailbox-specific identity mutation. Hybrid AC-026 remains incomplete until Phase 9 verifies live OAuth rejection/access, mailbox subpaths, and external-bypass exclusion. No live cluster commands were run.

## Review Loop

- Initial review recommended a custom CSP for raw message markup. The user subsequently chose normal Swoosh rendering for trusted synthetic previews behind OAuth; the custom policy and its dedicated test were removed. Runtime gating remains tested; CSRF, no-store, and default browser headers remain in the implementation.
- Reviewed the revised contract with security, performance, Elixir, and requirements reviewers; security also inspected the GitOps deployment boundary.
- Corrected an accidental runtime flag under ConfigMap metadata, re-rendered the manifest, and verified it appears only under `data`. Corrected grammar and stale conditional flag guidance found by requirements review.
- Final security, performance, Elixir, and requirements reviews found no remaining actionable findings after correcting the stale GitOps uncommitted-branch wording. The final mailbox suite focuses on the preview/runtime access conditions; live browser/proxy behavior and active AppSignal export were not exercised.

## Done Definition

- [x] Phase implementation and static verification complete
- [x] Tests and formatting pass
- [x] Reviews completed
- [x] Documentation validation passes
- Live deployment OAuth verification remains explicitly scheduled for Phase 9.

## PR Scope and Remaining Verification

- Torus: preview-only router forward and runtime flag check, reuse of browser/NoCache plugs, three unauthenticated access tests, removal of `test/oli/preview_qa_tools/build_policy_test.exs`, and synchronized requirements/design/plan/operator docs.
- GitOps: companion commit `f0e2b50` enables the flag and updates only the existing flag assertion and deployment guidance. `argocd/root/` is restored; no Argo CD, ingress, or service topology change remains.
- Current automated evidence is seven configuration tests and three mailbox tests. The earlier 79-test run is historical; its removed cases are not current coverage. Historical Phase 1/2 release checks also remain historical evidence, not a claim of a newly built production artifact.
- Phase 7/8 masquerade is unimplemented. Phase 9 retains current release/production artifact checks and live proxy/rollout QA. This PR completes the application mailbox phase without claiming full feature or live rollout completion.

## Decision Log

### 2026-09-24 - Prepare Phase 6 documentation for PR review
- Change: Reconcile the delivery plan, PRD, FDD, operator guidance, and execution evidence with the final minimal implementation and focused tests.
- Reason: Removed tests and GitOps checks were still described as present, and the default-seeding follow-on status was stale.
- Evidence: `lib/oli_web/router.ex`, `test/oli_web/preview_mailbox_test.exs`, `test/oli/preview_qa_tools/config_test.exs`, and GitOps commits `44438cc` / `f0e2b50`.
- Impact: Phase 6 is ready for PR review with explicit verification limits; later masquerade and rollout phases remain open.
