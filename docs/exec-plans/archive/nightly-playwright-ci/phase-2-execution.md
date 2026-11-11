# Phase 2 Execution Record

Work item: `docs/exec-plans/current/nightly-playwright-ci`
Phase: `2 — Shared Playwright configuration and atomic PR migration`

## Scope from plan.md

- Standalone Playwright compile configuration, runtime secrets and release branches.
- Compile-selected captcha verification, normal form submission and report privacy.
- Atomic PR workflow/environment migration, release assets and cache isolation.

## Implementation Blocks

- [x] Added standalone `config/playwright.exs`; removed `config/ci_e2e.exs` and active references. Scenario/mailbox gates, local mailer and captcha implementation are direct compile settings. Development reload/debug/watch behavior and preview QA defaults are absent; origin checking stays enabled.
- [x] Extended release runtime/SSL, endpoint gzip and Mix permanence for Playwright. Separate scenario/mailbox and captcha tokens are required at runtime; the private asset bucket remains optional for PR boot and required by asset operations. Compilation succeeds without deployment secrets.
- [x] `Oli.Recaptcha` fixes verifier selection at compile time. `Oli.Playwright.Recaptcha.verify/1` accepts only the current nonempty runtime captcha token with constant-time comparison. Missing/empty/incorrect/malformed responses fail without Google requests. Production keeps normal Google verification. All application call sites use the shared boundary.
- [x] Application captcha templates, scripts and LiveView hooks remain unchanged. No per-captcha branches, DOM inputs or deployed replacement client are needed. A shared runner context setup blocks Google scripts and supplies the token during native POST/LiveView form serialization. Registration, enrollment and payment retain their normal submit actions.
- [x] Required the captcha token in runtime configuration, generated a separate job-scoped PR secret and added the nightly protected environment input. No Google keys or public placeholder site key are needed. Account authentication and scenario/mailbox authorization remain enforced.
- [x] Added captcha parameter filtering; disabled traces/screenshots in CI and scenario/captcha-token-bearing local runs. Mailbox errors omit response bodies. Account-link navigation avoids credential-bearing `goto` step titles. Removed raw request-log artifact upload because paths contain confirmation/reset credentials.
- [x] PR workflow preserves triggers, checkout, permissions, `@pr` membership, create/migrate/seed and runner teardown. It generates job-scoped signing/encryption, scenario and captcha secrets, supplies explicit disposable service inputs, builds frontend/server/Tailwind/digested assets, and accepts only HTTP 200 from `/readyz`. Its exact cache key includes the environment/trust boundary, toolchain, configuration and lockfiles; there are no broad restore prefixes and only `_build/playwright` is cached.
- [x] The independent `nightly-scenarios` job is unchanged. Nightly image/cache orchestration remains in later phases.

## Test Blocks

- [x] Backend coverage checks token acceptance/rejection/rotation, no Google fallback, production Google success/failure handling, immutable compile selection, standalone configuration, runtime secret requirements and parameter filtering.
- [x] Mailbox authorization covers wrong tokens; controller expectations use the shared captcha boundary.
- [x] Existing account, enrollment and payment browser suites exercise real HTTP/LiveView forms with the runner-supplied token. New registration tests reject missing/incorrect credentials. Google’s challenge UI is outside this coverage.
- [x] Runner boundary tests cover native POST, actionless LiveView serialization, form replacement, native GET, submitter overrides, external frames and Google script blocking.

## Earlier Phase 2 Verification

The original Phase 2 work verified clean and cached Playwright compilation, configuration-change invalidation, release frontend/server/Tailwind/digested assets, explicit disposable boot settings, workflow/cache contracts, and the unchanged backend scenario job. All checks passed. Hosted workflows and packaged images remain later gates.

The initial backend run passed with 26 doctests and 9,349 tests. A subsequent client-substitution iteration passed 25 browser tests but reported one failure in the unchanged payment-table sorting test (`test/oli_web/live/payments_live_test.exs:218`); that test passed in an isolated 20-test backend run. These results describe earlier implementations. Current verification is recorded below.

## Historical Captcha Simplification Verification (2026-10-12)

The user selected unconditional backend acceptance to remove unnecessary captcha-specific test infrastructure. PRD, FDD, plan and AC-033/AC-037/AC-038 then described that decision. This decision and its verification are historical and superseded by the authorized review follow-up below.

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

- [x] Updated PRD, FDD, plan, requirements, build guide, automation guide and setup documentation for credential-protected Playwright verification and unchanged captcha markup.
- [x] Requirements retain proposed status; packaged release and operational acceptance proof belong to later phases.
- [x] Corrected the deployment-seeding audit to scan maintained automation inputs instead of generated dependencies/reports. Corrected the payment helper’s isolated request test to use a local fulfilled response; real redirects are covered by integration tests.

## Protected Form Audit

Registration and account-invitation LiveViews share `Components.Auth.registration_form`; markup and hooks remain unchanged. Instructor enrollment and payment-code redemption use native forms. The shared fixture configures token submission; manually created instructor and adaptive-authoring student contexts also call the setup. Canvas launch tests use provisioned users. Certificate verification, technical support, collaborator invitations and LTI registration use the same compile-selected verifier. Actionless LiveView forms are supported without changing their native GET behavior. Production continues to require Google verification.

## Review Loop

The earlier local security, performance, Elixir, TypeScript and UI reviews found no actionable issues. Requirements review identified stale references to the superseded captcha token/helper contract; those were corrected in PRD, FDD, plan and AC-005, then re-reviewed with no remaining findings.

## Remaining Operational Gates

Hosted GitHub Actions execution and image/release packaging were not run locally. Phase 3 verifies packaged production/Playwright isolation and runtime fixtures; later phases provision and activate the durable nightly deployment. No GitOps, Jira, registry or live deployment writes were performed.

## Review Follow-up (2026-10-12)

The user accepted both PR review findings: require an automation credential for captcha-protected submissions and establish a clean full-suite result before completing G2. The approved implementation replaces unconditional acceptance with runtime token verification and centralized runner setup, with no deployed client substitute or captcha markup changes.

Local verification passed after the fixes below. Earlier isolated reruns are not full-suite exceptions; historical failures remain recorded. G2 still requires hosted PR checks on the follow-up revision before landing.

- Initial full backend attempt: **26 doctests, 9,617 tests, 2 failures (75 excluded)**. Both were database checkout failures in `ProgressSimulationScenarioTest` while asset compilation and browser work were also running. A solo rerun with the same seed reproduced a shared-connection checkout failure and was stopped after that reproduction. `config/test.exs` now gives the shared sandbox a one-second queue target instead of DBConnection's 50 ms default, accommodating concurrent learner/preloader queries without dropping valid work. Production configuration, assertions and concurrency are unchanged; no tests are excluded or relaxed. The final full run below verifies this fix.
- Final full backend run: **26 doctests, 9,617 tests, 0 failures (75 excluded)** in 296.5 seconds, using `ERL_FLAGS="+S 4:4" mix test --seed 508627` against the dedicated task database. The ExUnit portion contained only normal progress and summary; no extra failures were excluded.
- Final browser selection: **32 passed** with retries disabled (18 `@pr` cases and 14 supplemental payment/support/instructor checks).
- Browser iteration corrected the disposable server's missing payment-provider configuration and the new rejection tests' cookie-consent wait. A combined run also exposed a shared runtime configuration leak in `student_payment/support.spec.ts`; its dummy URL/token now reset after each test.
- Security review found that `form.elements` omits image submitters. The helper now checks associated controls across the document, and regression cases cover external actions and GET overrides on image inputs. The reviewer reproduced the original leak with a synthetic token and confirmed the fix.
- Final `MIX_ENV=playwright` compilation with `--warnings-as-errors`, rebuilt release assets, disposable server boot and exact HTTP 200 `/readyz` passed. Browser verification used separate generated runtime tokens and no Google keys.
- Failure-artifact scanning found no runtime captcha/scenario/API credentials, including inside the HTML report's embedded archive. Traces and screenshots were disabled.
- Cleanup: stopped the disposable server, removed both task databases, and deleted temporary runtime secrets and raw logs.
- Automation-wide `tsc --noEmit` reports two unchanged `Window.liveSocket` typing errors in `assets/automation/src/systems/torus/pom/course/CourseManagePO.ts:130` and `assets/automation/src/systems/torus/pom/product/ProductsPO.ts:93`; no changed-file errors were reported. Targeted ESLint/Prettier passed. These existing errors are not represented as a passing typecheck.

## Done Definition

- [x] Phase implementation complete, including the approved security follow-up.
- [x] Full backend and affected browser verification pass and are recorded.
- [x] Follow-up security, performance, Elixir, TypeScript and requirements review complete with no remaining findings.
- [x] Postflight validation, YAML parsing, formatting and diff checks pass.
