# Phase 2 Execution Record

Work item: `docs/exec-plans/current/nightly-playwright-ci`
Phase: `2 — Shared Playwright configuration and atomic PR migration`

## Scope from plan.md

- Standalone Playwright compile configuration, runtime secrets and release branches.
- Compile-selected captcha verification, normal form submission and report privacy.
- Atomic PR workflow/environment migration, release assets and cache isolation.

## Implementation Blocks

- [x] Added standalone `config/playwright.exs`; removed `config/ci_e2e.exs` and active references. Scenario/mailbox gates, local mailer and captcha implementation are direct compile settings. Development reload/debug/watch behavior and preview QA defaults are absent; origin checking stays enabled.
- [x] Extended release runtime/SSL, endpoint gzip and Mix permanence for Playwright. The scenario/mailbox token is required at runtime; the private asset bucket remains optional for PR boot and required by asset operations. Compilation succeeds without deployment secrets.
- [x] `Oli.Recaptcha` fixes verifier selection at compile time. `Oli.Playwright.Recaptcha.verify/1` accepts every input, including missing, empty and malformed values, without configuration or Google requests. Production keeps normal Google verification. All application call sites use the shared boundary.
- [x] Application captcha templates, scripts and LiveView hooks remain unchanged. Removed all `test_mode?/0` branches, captcha response injection, the replacement client, the shared captcha helper and its fixture override. Registration, enrollment and payment submit their normal forms.
- [x] Removed the captcha token from runtime configuration, PR secret generation and nightly workflow inputs. No Google keys or public placeholder site key are needed. Account authentication and scenario/mailbox authorization remain enforced.
- [x] Added captcha parameter filtering; disabled traces/screenshots in CI and scenario-token-bearing local runs. Mailbox errors omit response bodies. Account-link navigation avoids credential-bearing `goto` step titles. Removed raw request-log artifact upload because paths contain confirmation/reset credentials.
- [x] PR workflow preserves triggers, checkout, permissions, `@pr` membership, create/migrate/seed and runner teardown. It generates job-scoped signing/encryption and scenario secrets, supplies explicit disposable service inputs, builds frontend/server/Tailwind/digested assets, and accepts only HTTP 200 from `/readyz`. Its exact cache key includes the environment/trust boundary, toolchain, configuration and lockfiles; there are no broad restore prefixes and only `_build/playwright` is cached.
- [x] The independent `nightly-scenarios` job is unchanged. Nightly image/cache orchestration remains in later phases.

## Test Blocks

- [x] Backend coverage checks unconditional Playwright acceptance, no Google fallback, production Google success/failure handling, immutable compile selection, standalone configuration, scenario-token boot requirements and parameter filtering.
- [x] Mailbox authorization covers wrong tokens; controller expectations use the shared captcha boundary.
- [x] Existing account, enrollment and payment browser suites exercise real HTTP/LiveView forms without captcha injection or interaction. Google’s challenge UI is outside this coverage.
- [x] Removed browser tests dedicated to the deleted captcha client/helper.

## Earlier Phase 2 Verification

The original Phase 2 work verified clean and cached Playwright compilation, configuration-change invalidation, release frontend/server/Tailwind/digested assets, explicit disposable boot settings, workflow/cache contracts, and the unchanged backend scenario job. All checks passed. Hosted workflows and packaged images remain later gates.

The initial backend run passed with 26 doctests and 9,349 tests. A subsequent client-substitution iteration passed 25 browser tests but reported one failure in the unchanged payment-table sorting test (`test/oli_web/live/payments_live_test.exs:218`); that test passed in an isolated 20-test backend run. These results describe earlier implementations. Current verification is recorded below.

## Final Captcha Simplification Verification (2026-10-12)

The user selected unconditional backend acceptance to remove unnecessary captcha-specific test infrastructure. PRD, FDD, plan and AC-033/AC-037/AC-038 now describe that decision. Earlier token/client designs are superseded; no captcha secret or client substitution remains.

- Work-item preflight validation passed.
- `MIX_ENV=playwright mix compile --warnings-as-errors` passed. A disposable local server booted with no captcha keys or token, and `/readyz` returned HTTP 200.
- Existing `@pr` suite: **4 passed**. Payment unlock/paywall and instructor invitation/enrollment specs: **13 passed**, with no captcha secret, Google keys, injected response or client substitute.
- Full `mix test`: **26 doctests, 9,348 tests, 2 failures (75 excluded)**. Both failures are in unchanged tests: `test/oli/mcp/auth_integration_test.exs:86` exceeded its strict timestamp tolerance (1,001 ms versus less than 1,000 ms), and `test/oli_web/live/workspaces/instructor_test.exs:363` expected a different instructor display order. No captcha/configuration tests failed.
- Isolated backend checks: **38 tests, 0 failures**, covering `test/oli/playwright`, MCP authentication and instructor workspace modules. Both unchanged tests that failed during the full-suite run passed in this isolated run.
- Targeted automation ESLint/Prettier, Elixir formatting, `git diff --check`, and postflight work-item validation (`--check all`) passed.
- Removed obsolete captcha secret references from runtime, workflows, application code, tests and active documentation; the audit found none remaining.
- Cleanup: stopped the local server, dropped both task-created databases, and deleted temporary runtime secrets and raw request logs.

## Readiness Test Simplification (2026-10-12)

- Removed `test/oli_web/views/readiness_view_test.exs`, which embedded an Elixir program and recompiled application source in child VMs for a synthetic environment matrix.
- Kept the normal readiness controller tests for exact response bodies, HTTP/HTTPS behavior, cache/session headers, startup/drain failures, private database errors and runtime metadata override rejection in the test build.
- Cross-build metadata inclusion/omission and immutable compiled identity remain explicit Phase 3 checks against actual Playwright/production releases. This follow-up does not claim that packaged cross-build verification has run.
- Retained readiness and health controller tests: **6 tests, 0 failures**, with clean ExUnit output. The dedicated test database was removed. No shared test configuration or support changed. Security, performance and Elixir reviews found no issues; work-item validation and `git diff --check` passed.

## Work-Item Sync

- [x] Updated PRD, FDD, plan, requirements, build guide, automation guide and setup documentation for unconditional Playwright verification and unchanged rendering.
- [x] Requirements retain proposed status; packaged release and operational acceptance proof belong to later phases.
- [x] Corrected the deployment-seeding audit to scan maintained automation inputs instead of generated dependencies/reports. Corrected the payment helper’s isolated request test to use a local fulfilled response; real redirects are covered by integration tests.

## Protected Form Audit

Registration and account-invitation LiveViews share `Components.Auth.registration_form`; markup and hooks remain unchanged. Instructor enrollment and payment-code redemption now submit without injected captcha responses. Canvas launch tests use provisioned users. Certificate verification, technical support, collaborator invitations and LTI registration use the same compile-selected verifier. Future Playwright submissions need no captcha helper; production continues to require Google verification.

## Review Loop

Final security, performance, Elixir, TypeScript and UI reviews found no actionable issues. Requirements review identified stale references to the superseded captcha token/helper contract; those were corrected in PRD, FDD, plan and AC-005, then re-reviewed with no remaining findings.

## Remaining Operational Gates

Hosted GitHub Actions execution and image/release packaging were not run locally. Phase 3 verifies packaged production/Playwright isolation and runtime fixtures; later phases provision and activate the durable nightly deployment. No GitOps, Jira, registry or live deployment writes were performed.

## Done Definition

- [x] Phase implementation complete.
- [x] Final browser/backend verification recorded, including the two full-suite exceptions above.
- [x] Final simplification review complete.
- [x] Postflight validation passes.
