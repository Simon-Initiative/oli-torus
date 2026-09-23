# Phase 4 Execution Record

Work item: `docs/exec-plans/current/secure-assessment`
Phase: 4 — trusted admission and independent session lifecycle

## Scope from plan.md

Bind current verified LTI evidence to one resolved section/page, issue a provider-neutral
scoped credential atomically, preserve independent ordinary entry, and support
current-token exit without an attempt-completion requirement.

## Implementation Blocks

- [x] Shared launch target and transactional admission
- [x] Independent cookie installation and current-token exit/disconnect
- [x] Retire deployment selector and add bounded telemetry

`LtiRedirect.resolve_target/2` reads the authoritative selected section resource once
from current claims. Legacy projections are refreshed only when their migration marker
is stale. Launch-time row locking keeps target resolution, policy recheck and token
insertion consistent with concurrent settings edits.

`SecureLaunch.admission/3` binds verified current subject, institution/registration,
deployment, context and direct page. Existing JWT/state/nonce validation and assertion
freshness remain unchanged. Provider-neutral `Admission`, `admit/2` and
`issue_session/2` check capability, graded page policy and enrollment. Insert failures
become bounded errors rather than token-bearing changeset logs.

The outer launch transaction commits before `UserAuth.install_session/3` installs
the cookie. Ordinary launch replaces only this browser's cookie, not any other token.
Secure entry clears this browser's remember-me cookie and assigns Phoenix's actual
`live_socket_id` to the token-local disconnect topic.

CSRF-protected `POST /secure-assessment/exit` deletes the exact token, then broadcasts
only its channel/LiveView disconnect topics. It redirects to a standalone signed-out
page; secure ordinary logout also ignores client return paths. Repeated exit is safe.
No attempt completion, browser-close callback, heartbeat, lease or account lock exists.

`TORUS_SEB_REQUIRED_LAUNCHES` runtime parsing/enforcement is removed. The old spike
documentation now describes resource policy and session-local entry. Admission and
explicit scoped revocation use bounded `[:oli, :secure_assessment, ...]` telemetry.

## Test Blocks

- [x] Admission and LTI binding matrix
- [x] Current-session lifecycle and isolation regression tests
- [x] Formatting, compilation and verification results

Coverage includes valid/missing/stale evidence, invalid JWT, wrong page/deployment,
ungraded target, disabled capability, generic-provider admission, enrollment/policy
rechecks, actual concurrent settings edits on separate PostgreSQL connections,
outer rollback and a controlled real token-insert failure. Signed ordinary launches
with an existing same-user secure cookie and obsolete selector remain ordinary.

Exit coverage includes active and finalized attempts, repeat exit, CSRF rejection,
remember-me removal, saved attempt preservation, unrelated token survival and a
connected ordinary channel. Connected assessment LiveViews exercise revoked-callback
denial and preservation of a second same-user secure view. LiveViewTest bypasses the
real WebSocket transport; the test separately verifies Phoenix's native socket-ID
and exact-topic disconnect contract. Real-browser close/reconnect remains integration
verification, not a claimed server-side close event.

Final regression command:

```sh
mix test test/oli/delivery/secure_assessment_admission_test.exs test/oli/lti/secure_launch_test.exs test/oli_web/controllers/lti_controller_test.exs test/oli_web/lti_redirect_test.exs test/oli_web/user_auth_test.exs test/oli/accounts/secure_session_test.exs test/oli_web/secure_assessment_authorization_test.exs test/oli_web/live/delivery/student/lesson_live_test.exs test/oli_web/live/delivery/student/prologue_live_test.exs test/oli_web/live/delivery/student/review_live_test.exs test/oli_web/controllers/page_delivery_controller_test.exs test/oli_web/controllers/user_session_controller_test.exs
```

Result: **361 tests, 0 failures, 39 existing exclusions**.
Focused database-failure/admission run: **48 tests, 0 failures**.
`MIX_ENV=test mix compile --warnings-as-errors` passed.
Formatting and `git diff --check` passed. Test boot still emits the pre-existing
analytics inventory sandbox-ownership message and legacy seeder deprecation warnings;
no test failures were suppressed.

## Work-Item Sync

Preflight validation passed. Earlier phase and spike work was preserved except the
obsolete deployment gate explicitly retired here. FDD telemetry names now match
implementation; the plan records G4 completion. Requirements remain at planned
verification status until the final phase.

Full shells and dependency/review adapters remain Phase 5. **Keep instance support
disabled for rollout until remaining implementation and integration gates pass.**

## Review Loop

Harness-review used separate security, performance, Elixir and UI reviewers under
`docs/CODEREVIEW.md`. Resolved review feedback:

- Skip section-wide migration locking for already-current projections.
- Add an actual token-insert failure test, not only a post-insert rollback test.
- Add a viewport declaration to the minimal signed-out document.

Security and performance re-review confirmed closure. The connected lifecycle check
also exposed and fixed the native LiveView transport-ID wiring gap. No blocking
Phase 4 review findings remain. Browser/SEB integration is still a rollout requirement.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed
- [x] Postflight validation passes
