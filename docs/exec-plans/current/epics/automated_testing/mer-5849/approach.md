# MER-5849 Credential-Based Account Flow Playwright Coverage

## Purpose

Add deterministic Playwright coverage for email/password account lifecycles without
depending on real inboxes or the nightly suite's persistent deployments.

## Decision Summary

### Reuse the existing Playwright environment gate

The email-inspection routes will be mounted only when
`Application.compile_env(:oli, :enable_e2e_mailbox, false)` is enabled in the
dedicated E2E environment. They will use the existing `OliWeb.PlaywrightAuth`
token check.

This deliberately extends the test-only boundary established by MER-5171:
`/test/scenario-yaml` already uses this compile-time gate and the same secret to
let a Playwright-enabled deployment construct its own isolated test state. A
separate email-specific flag would duplicate that deployment contract without
providing an additional security boundary.

Production and ordinary staging deployments keep this flag disabled. A
Playwright-specific ephemeral deployment must enable it, use an isolated
database, and supply its scenario token.

### Reuse the local mailbox, not the mailbox-preview UI

The Playwright environment will configure `Oli.Mailer` with
`Swoosh.Adapters.Local`. A small JSON controller under `/test` will read the
same local mailbox data. It is a machine contract for browser tests; it does
not automate or change `/dev/mailbox`, which remains a human-oriented
development preview.

The API will support a recipient filter and stable message detail lookup. The
list response will include enough metadata to select a message by recipient
and subject; the detail response will expose the HTML and text bodies needed
to extract a confirmation or reset URL.

### Select emails by recipient and purpose, never by arrival order

Each test creates a unique address. A single lifecycle produces both
`Confirm your email` and `Reset password` messages, delivered asynchronously
through Oban. The TypeScript mailbox helper will poll by the unique recipient
and exact subject, then request the selected message by identifier. It must
not assume that the newest message is the intended one.

## Coverage Contract

| Account case | Provisioning | Browser-driven coverage |
| --- | --- | --- |
| Standard Author | Self-service `/authors/register` | Registration, confirmation, login, reset, old-password rejection, new-password login, Authoring destination |
| Independent learner | Self-service `/users/register` | Registration, confirmation, login, reset, old-password rejection, new-password login, Delivery destination |
| System admin | Scenario-seeded Author with admin role | Login, reset, old-password rejection, new-password login, admin/Authoring destination |
| Instructor | Scenario-seeded User with instructor capability | Login, reset, old-password rejection, new-password login, Instructor destination |

Admin and instructor accounts are seeded because Torus has no public
self-service registration flow for either privilege. They extend credential
coverage across the Authoring and Delivery role boundaries without testing a
non-existent registration feature.

## Boundaries And Non-Goals

- Do not add a public mailbox endpoint, runtime adapter switching, or a second
  automation authorization mechanism.
- Do not put these tests in the `@nightly` suite, which targets persistent
  environments.
- Do not change the credential lifecycle semantics, authorization rules, or
  production email delivery adapter.
- Do not automate `/dev/mailbox` HTML.
- The registration flows require deterministic E2E handling of reCAPTCHA; the
  approach must avoid a real external challenge during CI.

## Implementation Outline

### Phase 1: E2E foundation

- Add guarded mailbox JSON endpoints and focused controller/authorization
  tests, reusing `OliWeb.PlaywrightAuth`.
- Configure the dedicated Playwright environment with the Local adapter and
  deterministic reCAPTCHA handling for both account types.
- Add the TypeScript mailbox polling helper.

**Exit criterion:** the application exposes no mailbox data without the
existing Playwright token, and a browser test has a deterministic path to
wait for a Local-adapter email.

### Phase 2: Self-service lifecycle coverage — complete

- Add credential-account page objects or focused task helpers.
- Add complete Author and independent-learner browser flows: registration,
  confirmation, login, reset, old-password rejection, and new-password login.
- Generate a unique recipient per flow, select the message by recipient and
  subject, and extract only the expected account-action URL (rather than an
  unrelated link such as the email logo).
- Dismiss the cookie-consent modal when it is present before a credential-flow
  action, so an unrelated asynchronous UI overlay cannot obscure its control.
- Wait for the confirm/reset LiveViews' post-submit redirect using
  `waitUntil: 'commit'` rather than the default `'load'`. These redirects are
  pushed by LiveView over the existing WebSocket
  (`Phoenix.LiveView.redirect/2`, a cross-document navigation), and Chrome did
  not reliably report the resulting `load` event to Playwright even though the
  navigation and render completed; waiting for `'commit'` avoids depending on
  that event.
- When simulating an anonymous confirmation or reset-password click (i.e. not
  as the just-registered, auto-logged-in account), clear only the session
  cookie (`context.clearCookies({ name: '_oli_key' })`) instead of every
  cookie. Clearing all cookies also discarded the cookie-consent choice,
  re-triggering the consent modal on the next navigation and racing with the
  credential-flow submit it was meant to protect.

**Exit criterion:** both self-service account types complete their lifecycle
against a Playwright environment without a real inbox or external reCAPTCHA.

### Phase 3: Provisioned-role credential coverage — complete

- Seed a system admin Author (`system_role: system_admin`) and an instructor
  User (`type: instructor`, `can_create_sections: true`) via the existing
  scenario-YAML mechanism
  (`assets/automation/tests/torus/user_accounts/playwright_credential_roles.yaml`),
  reusing `seedScenario`/`/test/scenario-yaml` rather than factories or direct
  database writes. Seeded accounts are pre-confirmed
  (`email_verified` defaults to `true`), so no confirmation step is exercised
  for these roles — only login, reset, old-password rejection, and
  new-password login.
- Cover both roles in
  `assets/automation/tests/torus/user_accounts/credential-account-provisioned-roles.spec.ts`,
  reusing `CredentialAccountPO` from Phase 2 rather than the older
  `HomeTask`/`LoginPO` role-picker stack.
- Assert the role-specific destination and an account-menu role label
  (`[role="account label"]`, e.g. "Admin"/"Instructor") after each successful
  login, not just a successful authentication.
- A plain `/users/log_in` submission always redirects to
  `/workspaces/student`, even for a `can_create_sections: true` user: the
  redirect target is computed before `current_user` is assigned onto the
  `conn` (`lib/oli_web/user_auth.ex:23-41`). Reaching `/workspaces/instructor`
  requires logging in through `/instructors/log_in`, whose form action embeds
  `request_path=/workspaces/instructor` directly
  (`lib/oli_web/live/user_login_live.ex:47`). `CredentialAccountPO.login`
  therefore takes an optional `loginPath` override used only for the
  instructor case; the system-admin Author already lands on the regular
  `/workspaces/course_author` via `/authors/log_in`, distinguished only by the
  "Admin" account-menu label.
- Do not run both credential-flow spec files concurrently against the same
  Playwright server/`test-results` directory (e.g. one from a terminal, one
  from `--ui`); a single observed hang and a single unrelated trace-file
  `ENOENT` both coincided with concurrent runs and did not reproduce across
  22 clean, sequential runs.

**Exit criterion:** Authoring and Delivery privileged roles prove their
credential reset behavior without pretending that they have self-service
registration flows.

### Phase 4: CI/CD integration and operational closure — complete

- Added `.github/workflows/pr-playwright.yml`, triggered on `pull_request` to
  the same branches as the main `build.yml` CI (`master`, `hotfix-*`,
  `prerelease-*`, `nextgen-ux`). It starts an ephemeral
  `pgvector/pgvector:pg18` service-container database (destroyed with the
  runner, satisfying the ticket's "reset the CI test database after the run"
  without an explicit teardown step), compiles and boots Torus under
  `MIX_ENV=ci_e2e`, polls `/` until ready, then runs every `@pr`-tagged
  test. Named and worded generically on purpose (no MER-5849/credential
  wording in the workflow file itself): it is meant to be the durable,
  reusable home for any future Playwright test that can run against a bare,
  freshly created database, not a one-off tied to this ticket.
  `HOST` and `PLAYWRIGHT_BASE_URL` are both set to `localhost` — see the
  Phase 2 note above on why they must match.
- `PLAYWRIGHT_SCENARIO_TOKEN` is a fixed, non-secret string
  (`ci-ephemeral-token`) rather than a GitHub secret: the instance it protects
  is unreachable outside the job and destroyed when it ends, so the token has
  no value to protect beyond this one run.
- When the job fails, it uploads the Playwright report/trace/test-results and
  the Torus server's stdout/stderr, redirected to a file when the server is
  started. Successful runs do not retain redundant diagnostics;
  `nightly-playwright` does not need the server log because it targets an
  already-running, separately-logged deployment.
- Test selection uses an explicit Playwright tag, `@pr`, applied to both
  `credential-account-flows.spec.ts` and
  `credential-account-provisioned-roles.spec.ts` describe blocks, run via
  `npx playwright test --grep @pr`. This mirrors the existing `@nightly`/
  `@smoke` tagging convention (single lowercase word naming *when/where* a
  test runs, not what it tests) rather than inventing a new mechanism, and is
  the semantic inverse of `@nightly` the ticket asked about, extensible to
  future non-nightly, non-smoke suites without editing the workflow file.
- **Rejected:** reusing the "Plasma" per-PR preview deployment
  (`build-preview-image.yml`, `plasma.oli.cmu.edu`) that a ticket comment
  suggested investigating. Plasma's actual deployment step is reconciled by
  Argo CD in a private GitOps repository not present in this codebase, and
  every Plasma preview is currently built as a shared, human-reviewable
  `MIX_ENV=prod` image (real AWS SES mailer, no scenario/mailbox routes) —
  changing that for all previews to get this suite's `MIX_ENV=ci_e2e`
  behavior is out of this repo's reach and out of this ticket's scope. A
  fully self-contained job satisfies the ticket's own step-by-step "CI/CD
  Integration" section without depending on that external infrastructure.
- **Deferred, not built:** flipping test selection from opt-in (`@pr`) to
  opt-out (`--grep-invert "@nightly|@smoke"`, so any newly added spec runs
  here by default) is mechanically possible but not done. Several existing
  suites under `assets/automation/tests/torus/` (LTI external tool, course
  authoring, Google Docs import, Canvas) assume a persistent, pre-seeded
  environment and real third-party credentials that this minimal, empty
  ephemeral instance does not provide; inverting the grep today would run
  them here and fail them for environment reasons unrelated to real bugs.
  Doing this safely later requires first auditing and tagging (e.g.
  `@requires-persistent-env`) every suite that cannot run against a bare
  ephemeral instance.

**Exit criterion:** pull-request or equivalent CI can run the suite on an
ephemeral Playwright deployment without touching persistent staging or
production systems.

## Risks And Verification

- **Async delivery:** poll the mailbox with bounded timeouts and include the
  mailbox response in failure diagnostics where safe.
- **Secret exposure:** require the existing token for every mailbox route;
  test missing and invalid-token responses.
- **Parallel interference:** use a generated address per test and server-side
  recipient filtering.
- **Environment drift:** verify mailbox routes are present only when the
  dedicated E2E mailbox flag is enabled, and run the suite only against the
  dedicated CI deployment.
- **`PLAYWRIGHT_BASE_URL` must match the server's `HOST`:** Playwright resolves
  every relative `page.goto(...)` against `PLAYWRIGHT_BASE_URL`, but the
  server builds the absolute confirmation/reset links embedded in emails from
  `HOST` (`config/dev.exs:108`, inherited by `config/ci_e2e.exs`). If the
  two values name different hosts (e.g. `PLAYWRIGHT_BASE_URL=127.0.0.1` with
  `HOST=localhost`), the browser reaches the emailed link on an origin it has
  never visited, so no cookie set earlier in the flow (including the
  cookie-consent choice) is present there. The consent modal then has to
  mount fresh, asynchronously, on that page, racing the credential-flow
  submit and intermittently blocking it — reproducible headed or in `--ui`
  mode, not just headless. Keep `PLAYWRIGHT_BASE_URL` and `HOST` set to the
  same hostname for any local or CI Playwright run.
- **Role drift:** assert role-specific post-login destinations for admin and
  instructor, not merely successful authentication.

Verification will include focused ExUnit controller tests, TypeScript linting
and formatting, the targeted Playwright account-flow suite against the
dedicated environment, and CI artifact checks for a forced or captured
failure path.
