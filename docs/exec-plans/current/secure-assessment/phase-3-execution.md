# Phase 3 Execution Record

Work item: `docs/exec-plans/current/secure-assessment`
Phase: 3 — shared authorization across transports

## Scope from plan.md

Enforce canonical assessment ownership and current-token scope before protected work in HTTP, LiveView and channels. Preserve ordinary-session independence. Production admission remains deferred to Phase 4 and dependency completion to Phase 5.

## Implementation Blocks

- [x] Canonical target resolution and shared policy
- [x] HTTP and connected transport adapters
- [x] Bounded denial telemetry and batch resolution

Implemented:

- `SecureAssessments.Target`, `resolve_page/2`, `resolve_attempts/3`, scope/owner/
  resource checks and whole-batch parent validation. Attempt resolution is one
  joined query, including page/activity pinned revision IDs. Limits apply before
  resolution: 100 read identifiers, 1,000 nested mutation identifiers and 100 state
  projection keys. Duplicate mutation GUIDs, malformed IDs and unresolved members
  reject the complete request before mutation.
- `UserAuth` projects only the presented token. The HTTP boundary uses trusted
  router metadata before delivery redirect/context pipelines. It guards basic,
  adaptive and legacy page paths, index navigation, attempts/parts, lifecycle,
  resource-attempt state, known attempt blobs and protected model/tool/report/
  discussion dependencies. Unmapped routes are denied for scoped credentials.
- Router LiveView hooks reload the exact session before protected mounts, events,
  navigation, messages and asynchronous callbacks. One-at-a-time components have
  their own check. Score-as-you-go messages validate their canonical activity and
  page. Ordinary unrelated LiveView callbacks retain a zero-policy-query fast path.
- Version-2 socket capabilities carry a purpose-signed token-row reference, never
  a bearer token. All existing channel families reject scoped sessions. Ordinary
  channels validate ownership/enrollment and current protected-discussion policy;
  deleted/expired row-backed credentials cannot join or emit delayed/outbound data.
  Legacy ordinary capabilities confer no protected discussion entitlement.
- Denials are bounded telemetry events without IDs, claims, answers or tokens.
  Mapped assessment success responses and denials are `no-store`. JSON denials have
  stable reason codes; HTML recovery has a title, language, viewport and landmark.
- Unscoped embedded assistant/support/system-message/outline surfaces are omitted
  for secure delivery. Page-scoped ordinary assistant callbacks also recheck token
  validity and current resource policy. This limited rendering change closes
  connected side channels; it is not the full Phase 5 assessment-only shell.

## Test Blocks

- [x] Negative authorization and noninterference tests
- [x] Existing regression suites
- [x] Results captured

Final broad verification command:

```sh
mix test test/oli_web/secure_assessment_authorization_test.exs test/oli_web/controllers/api/attempt_controller_test.exs test/oli_web/controllers/api/resource_attempt_state_controller_test.exs test/oli_web/controllers/page_delivery_controller_test.exs test/oli_web/live/delivery/student/lesson_live_test.exs test/oli_web/live/delivery/student/prologue_live_test.exs test/oli_web/live/delivery/student/review_live_test.exs test/oli_web/live/dialogue/window_live_test.exs test/oli_web/user_auth_test.exs test/oli/accounts/secure_session_test.exs test/oli_web/controllers/activity_controller_test.exs test/oli_web/controllers/api/page_lifecycle_controller_test.exs test/oli_web/controllers/api/blob_storage_controller_test.exs test/oli_web/controllers/legacy_superactivity_controller_test.exs test/oli_web/controllers/api/lti_controller_test.exs test/oli_web/controllers/api/lti_controller_integration_test.exs test/oli_web/controllers/lti_ags_controller_test.exs test/oli_web/controllers/api/directed_discussion_controller_test.exs
```

Result: **391 tests, 0 failures, 41 existing exclusions**. The final focused
authorization rerun passed **20 tests, 0 failures**, including the added mixed
author/secure-cookie regression. Earlier intermediate failures were fixed:
router metadata timing, embedded LiveView navigation-hook attachment, preservation
of unprotected review semantics, a HEEx condition and ordinary author-preview
capabilities. No authorization failures were hidden with skipped tests.

New coverage includes forged review query parameters; ordinary protected entry;
wrong owner/parent/resource; mixed batches with unchanged responses; pinned/dynamic
model membership; component forgery and revoked credentials; legacy/row-backed
socket denial; bounded telemetry; one-query batch resolution and zero-query ordinary
callback fast paths. Real connected tests cover secure score notifications and
revocation before `begin_attempt`, while another ordinary token remains valid.

`MIX_ENV=test mix compile --warnings-as-errors`, targeted formatting and
`git diff --check` passed. Existing startup analytics sandbox-ownership logging,
seed deprecation and intentional legacy-controller error logs remain outside this
phase. New intentional telemetry test logging is captured. No production rollout,
full backend/frontend suite, browser pilot or cross-node claim is made here.

## Work-Item Sync

- Preflight work-item validation passed.
- [x] Reconcile implementation boundaries and outstanding gates

- `design/boundaries.md` now records actual enforcement and fail-closed Phase 5
  dependencies; FDD records the concrete resolver interfaces.
- One old lifecycle test now expects typed 404 for a nonexistent GUID, rather than
  a successful HTTP envelope containing failure. An extrinsic-state fixture now
  installs real section resources so authoritative policy lookup is exercised.
- Finalized secure attempts cannot use active-delivery API data/write operations;
  explicit page review retains existing ReviewPolicy/feedback rules. Phase 5 must
  add the finalized dependency-read adapters and full renderer review support.
- Requirements remain `verified_plan`; this is not complete-feature acceptance.
  Admission/exit remain Phase 4; renderer/dependency completion remains Phase 5;
  comprehensive independent-cookie/AGS and real SEB evidence remain Phases 6–7.

## Review Loop

Completed harness-review with dedicated security, performance, Elixir and UI
reviewers following `docs/CODEREVIEW.md`. Fixed findings:

- Bind review authorization to trusted route/view, not client parameters.
- Guard direct external-tool launch details and prevent protected response caching.
- Revalidate nested page-assistant callbacks and omit unscoped embedded surfaces.
- Permit canonical secure score notifications without ending valid delivery.
- Avoid ordinary unrelated callback queries and repeated parent lookups per array.
- Reject malformed navigation-index shapes without an exception.
- Add accessible standalone denial document structure.

Security re-review confirmed closure; no concrete Phase 3 security blocker remains.
Full renderer dependency enablement and production admission are deliberately not
claimed by this review.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed
- [x] Work-item validation passes

G3 is satisfied for the enforcement infrastructure and fail-closed dependency
boundaries. Keep capability disabled in production until the remaining phase gates
pass; no browser launch currently issues a secure token through this implementation.
