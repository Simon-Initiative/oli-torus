# Secure assessment boundary and verification contracts

Phase 1 inventory, based on the current branch. This document specifies later implementation; no listed guard or adapter is claimed to exist yet. Governing design: `docs/exec-plans/current/secure-assessment/fdd.md`. Scope is the current credential only, never the learner account.

## 1. Placement and default rules

Authenticate the presented credential, classify the server operation, resolve canonical ownership, check current-token scope and resource policy, then construct context/read/mutate. Explicit authentication/exit routes do not inherit an old token's navigation restriction. Ordinary scope immediately passes navigation confinement, but protected-resource checks still apply.

`lib/oli_web/router.ex` currently places `:redirect_by_attempt_state` before `:delivery_protected` for prologue/lesson/adaptive routes. Insert the new authorization boundary before redirect/context work, not merely at the end of the existing protected pipeline. Also cover older page routes, which use a different pipeline. LiveView `InitPage` must not load sensitive content before authorization.

Every learner route not explicitly classified as assessment delivery/dependency/authentication/exit is denied for a scoped token. This includes course dashboards, containers, assignments, other sections, authoring/preview escapes and administration. Ordinary authorization remains unchanged. Public static assets remain available; an `/api` prefix does not make a route a safe dependency. Mixed author/student cookies cannot bypass scope.

## 2. Route and operation matrix

Paths below are router paths; `:section_slug`, revision slugs and GUIDs are untrusted locators, not authority. Test names are planned test cases, grouped by the suite keys in section 6.

| ID | Existing entry / implementation owner | Operation and canonical target | Required guard / planned test |
| --- | --- | --- | --- |
| B01 | `/lti/login`, `/lti/launch`; `lib/oli_web/controllers/lti_controller.ex`, `lib/oli_web/lti_redirect.ex`, `lib/oli/lti/secure_launch.ex` | `:authentication`; verified current user, deployment/context section and exact direct page | Phase 4: share target resolution; protected entry needs adapter evidence; ordinary entry replaces current cookie without other-token queries. LTI: `current_target_and_stale_cookie`, `former_selector_does_not_block_ordinary` |
| B02 | `/users/log_in`, `/users/log_out`, auth callbacks; `lib/oli_web/user_auth.ex`, user session controller | `:authentication`, `:exit`; current token | Phase 4: explicit route classification, CSRF and token-specific deletion/disconnect. AUTH: `independent_credentials_and_exit` |
| B03 | `/sections/:section_slug/prologue/:revision_slug`, `/lesson/:revision_slug`, `/adaptive_lesson/:revision_slug` | `:prologue`, `:deliver`; section resource; pinned attempt when present | Phase 3: before `RedirectByAttemptState`, `InitPage` and `PageContext.create_for_visit`. WEB: `all_current_page_routes_before_context` |
| B04 | Legacy `/page/:revision_slug`, `/page_fullscreen/:revision_slug`, `/page/:revision_slug/page/:page`; `PageDeliveryController` | `:deliver`; same page, pagination is internal | Phase 3: same resolver as B03, not a separate allowlist bypass. WEB: `legacy_page_aliases` |
| B05 | GET `/page/:revision_slug/attempt`, POST `/page/:revision_slug/attempt_protected`; PrologueLive `begin_attempt` | `:start`; authoritative page and existing lifecycle | Phase 3: check before attempt creation/resume, retain password/date/accommodation rules. WEB: `start_variants_no_side_effect_on_denial` |
| B06 | POST `/sections/:section_slug/page` (`navigate_by_index`); `/container/:revision_slug`, course index/learn/assignments and preview routes | Resolve index destination; deny unrelated destinations/routes for scope | Phase 3: guard destination before redirect, never allow whole section. WEB: `index_navigation_and_preview_escape` |
| B07 | `/lesson/:revision_slug/attempt/:attempt_guid/review`, adaptive and legacy review aliases; ReviewLive, PageDeliveryController | `:review`; owned finalized ResourceAttempt → ResourceAccess → page; pinned revision | Phases 3/5: submitted/evaluated plus ReviewPolicy and feedback projection; ordinary permitted review independent of S. REVIEW: `all_review_aliases_read_only` |
| B08 | POST `/api/v1/state/course/:section_slug/activity_attempt` (`bulk_retrieve`); GET `/:activity_attempt_guid` | `:dependency_read`; every activity attempt → resource attempt → access/user/page | Phase 3: authorize entire set before model/response serialization. API: `bulk_retrieve_mixed_targets_and_feedback` |
| B09 | Activity attempt POST/PATCH/PUT; `/active`, `/evaluations`; `Api.AttemptController` | `:start`, `:save`, `:submit`; parent activity plus every supplied part | Phase 3: cross-check URL activity and all body GUIDs before lifecycle calls. API: `nested_parts_match_parent_all_or_none` |
| B10 | Nested part POST/PATCH/PUT, `/active`, `/hint`, `/upload` | `:start`, `:save`, `:submit`, or dependency read/write; full part/activity/resource/access chain | Phase 3: hints may change hint state and are not review reads; upload authorization precedes file storage. API: `part_parent_hint_upload_boundaries` |
| B11 | POST `/api/v1/page_lifecycle` (`finalize`, `mark_completed`); LessonLive `finalize_attempt` | `:submit`; reconcile body section/revision/attempt and authenticated actor | Phase 3: protect both actions before finalization/progress mutation, preserve idempotency. LIFECYCLE: `finalize_and_mark_completed_ownership` |
| B12 | GET `/api/v1/storage/course/:section_slug/resource/:resource`, POST `/api/v1/storage/course/:section_slug/resource`; `Api.ActivityController.retrieve_delivery/bulk_retrieve_delivery` | `:dependency_read`; resource IDs must belong to pinned page/actual selected activity tree | Phases 3/5: section access alone insufficient, including mixed preview cookies. MODEL: `pinned_model_membership_and_redaction` |
| B13 | GET/PUT/DELETE `/api/v1/state/course/:section_slug/resource_attempt/:resource_attempt_guid` | dependency read/write; ResourceAttempt → ResourceAccess | Phases 3/5: actor/page plus read-only mode, not arbitrary GUID. STATE: `attempt_state_modes_and_cross_target` |
| B14 | GET/PUT/DELETE `/api/v1/state` and `/api/v1/state/course/:section_slug` | dependency read/write only through explicit assessment-owned adapter | Phases 3/5: no whole-user/whole-section fetch for secure scope. STATE: `extrinsic_projection_not_global_exemption` |
| B15 | GET/PUT `/api/v1/blob/:key`, `/api/v1/blob/user/:key`; `Api.BlobStorageController` | dependency read/write; attempt GUID mapping or declared key projection | Phases 3/5: opaque keys do not confer ownership; do not allow user-wide blob namespace. STATE: `blob_key_resolution_and_review_denial` |
| B16 | `/jcourse/superactivity/context/:attempt_guid`, POST `/jcourse/superactivity/server`; `LegacySuperactivityController` | classify `commandName` after resolving `activityContextGuid` to canonical attempt | Phases 3/5: these use `:api`, not `:delivery_protected`; explicit guard required. EMBED: `command_dispatch_scope_and_review` |
| B17 | `/api/v1/lti/sections/:section_slug/launch_details/:activity_id`, deep-linking variant; platform authorization/return | dependency read/launch; activity membership plus parent attempt and mode | Phases 3/5: server-bound parent/mode through login hint and return; configuration/deep-linking is not student delivery. TOOL: `tool_parent_binding_and_read_only_launch` |
| B18 | `/lti/lineitems/:page_attempt_guid/:activity_resource_id/results`, `/scores`; `Api.LtiAgsController`; background grade updates | service authorization, not learner navigation privilege | Phase 6: retain AGS token/ownership checks and resource grade binding. TOOL: `service_auth_and_interleaved_passback` |
| B19 | Discussion API, activity reports, delivery xAPI, ECL evaluation, media proxy, trigger/scheduling routes | default deny for scope unless proven assessment dependency; then explicit parent/operation adapter | Phases 3/5: do not exempt all telemetry/media/evaluation routes; xAPI actor/target server-derived. WEB: `auxiliary_routes_require_classification` |
| B20 | Project storage/media/package routes; `/jcourse/superactivity/preview_context`; `/jcourse/dashboard/log/server` | authoring/preview denied to scoped student; required delivery logs get narrow adapter | Phases 3/5: test mixed-cookie and legacy pipeline bypasses. EMBED: `preview_and_authoring_not_secure_escape` |
| B21 | Other router families: workspaces, section management, payments, account settings, AI/MCP, admin/dev routes | deny scoped navigation by default; ordinary and independently authenticated services keep their rules | Phase 3: router coverage test classifies every route and detects additions. WEB: `unclassified_secure_routes_fail_closed` |
| B22 | `/set_session`, timezone/preferences, cookie consent, research consent, unauthorized/not-found and signed-out surfaces | narrow session/required-accessibility operation or confined explanation; never a client scope mutation | Phase 3: explicitly classify required ancillary requests without granting navigation; submitted maps cannot set scope/provider/mode. WEB: `session_utilities_cannot_unconfine`; preserve ordinary consent flows |

Public asset delivery is allowed, but a proxy accepting a URL must not become unrestricted data retrieval for secure credentials.

## 3. Connected execution inventory

| Owner | Execution boundary | Planned verification |
| --- | --- | --- |
| UserAuth and live-session hooks | Disconnected/connected mounts, reconnect, current credential validity; InitPage before content initialization | WEB `mount_and_reconnect_revalidate_exact_token`; AUTH `expired_scope_never_falls_back` |
| `lib/oli_web/live/delivery/student/prologue_live.ex` | `begin_attempt`; `:gc` is housekeeping, not authority | WEB `revoked_token_cannot_begin_from_mounted_view` |
| `lib/oli_web/live/delivery/student/lesson_live.ex` | `finalize_attempt`, `select_question`, `handle_params`; annotation/discussion/search/sidebar handlers; async `{ref, result}`, question-disable messages and `:fire_trigger` | WEB `mounted_events_and_delayed_results_recheck`; deny unrelated UI handlers and strip their initial data, while preserving assessment-internal navigation |
| `lib/oli_web/live/delivery/student/lesson/components/one_at_a_time_question.ex` | Component-targeted `submit_selected_question`, `activity_saved`, `select_question`; evaluation and refreshed feedback | WEB `component_guid_cannot_cross_assessment`; parent LiveView hooks alone are insufficient |
| Outline component and ReviewLive | Outline `update`/`expand_item` denied or removed in secure shell; ReviewLive initialization and survey script callbacks retain read-only contract | REVIEW `review_initial_payload_and_callbacks`; SHELL `no_outline_payload` |
| `lib/oli_web/channels/user_socket.ex`, SetToken plug | Current credential signs user identity and socket ID is nil; planned secure capability signs exact session record with distinct purpose | SOCKET `secure_signature_expiry_and_deleted_row`, `ordinary_socket_stays_connected` |
| GlobalUserStateChannel / SectionUserStateChannel | `join`, deferred `after_join` initial state, `delta` and `deletion` pushes | SOCKET `global_topics_denied_for_secure`, `delayed_read_and_outbound_revalidate`; never trust topic user ID or section |
| DirectedDiscussionChannel / ClickhouseChunkLogsChannel | Scoped student denied; existing ordinary/service authorization remains | SOCKET `unrelated_topics_denied`; if required by actual activity, add an assessment-targeted adapter rather than allowing these broad subscriptions |

Scope checks must occur before sensitive `send_update`, push, rendering or async-result application, not just when work is scheduled. PubSub disconnect improves responsiveness but is not the authority check. No new background heartbeat is introduced.

## 4. Dependency contracts and integration backlog

| Dependency / observed caller | Canonical ownership and read/write contract | Phase 5 implementation and Phase 7 evidence |
| --- | --- | --- |
| Basic activity delivery via `assets/src/data/persistence/state/intrinsic.ts` | Activity/part hierarchy; active save, submit/evaluation, reset and hints retain existing lifecycle | Exercise multipart basic content, one-at-a-time submission and forged parent IDs; finalized review rejects all mutations |
| Adaptive bulk screen load in `assets/src/apps/delivery/store/features/groups/actions/deck.ts` | `getBulkAttemptState` receives the activity-attempt mapping; absent mapping can use delivery model lookup | Authorize selected dynamic/bank/nested activities through actual attempt membership and pinned content, not solely current `related_activities`; verify reload and review screen navigation |
| Adaptive page state in `state/intrinsic.ts` | Provider `deprecated` uses resource-attempt state endpoint; provider `new` uses Blob.read/write(resourceAttemptGuid) | Both storage paths resolve the same owned ResourceAttempt; preserve saved keys and mode semantics; test both providers, no migration to empty state |
| Adaptive startup `page/actions/loadInitialPageState.ts` | `session.visits.*`, `visitTimestamps.*`, tutorial/current score, timing, attemptNumber, resume belong to attempt; `app.active` initializes local app state | Preserve deadline/resume snapshots. REVIEW skips initial persistence and uses attempt snapshot including `app.*`, rather than reading current global state |
| EverApp startup reads in the same file | `content.custom.everApps[].id`; new blob provider additionally requests `explorations` and `0`; result flattened into `app.<id>.<subKey>` | Build server-selected dependency manifest from pinned content. Project only keys genuinely needed by this assessment, snapshot relevant shared inputs into attempt state, and route secure writes to assessment-owned state. Test nonempty pre-existing values, restart and independent ordinary values; no automatic blanket approval of `explorations`/`0` |
| Adaptive `adaptivity/actions/triggerCheck.ts`, deck/footer actions | Extract `session.*` and `app.*` snapshots; nested activity trees can persist/evaluate outside initial-load function | Audit each write site and explicit key mapping; review must suppress all persistence/evaluation, not only startup. SHELL/STATE tests spy on writes and assert server rejection |
| Extrinsic/blob clients `assets/src/data/persistence/extrinsic.ts`, `blob.ts` | Global/section read, upsert/delete, user blobs currently lack parent assessment identity | Add parent-attempt-aware entry points with server-owned manifest. Preserve required shared-read semantics; do not expose all user data or accept a client-provided key allowlist |
| Superactivity context and commands | `LegacySuperactivityController.fetch_context` resolves runtime context; command dispatcher can start/end attempts, score and manipulate saved files | Classify each dispatcher clause as read or write; bind saved file directory/record to canonical attempt. `loadClientConfig`, `beginSession`, `loadContentFile` need review-safe responses; start/end/scoring/file changes must not mutate review. Pilot embedded content and saved-file review |
| External LTI tool | Section launch-details currently creates login hint with section/resource; not an explicit parent page attempt/review contract | Bind hint, authorization, return and grade callback to assessment attempt and access mode. Verify provider read-only review capability with integration content; normal launch is not proof of review support. Implement missing adapter behavior before enablement, no page-type exclusion |
| Media/upload | Part upload uses encoded file and parent GUIDs; embedded packages/media have separate authoring operations; static published assets may be public | Authorize upload and private download/signed URL issuance before storage access; serve only required delivery asset dependencies. SEB URLs/configuration tested with actual audio/video/images/files and external host returns |
| AI feedback, discussion/report/xAPI and ECL | May be invoked by content or delayed jobs but are not automatically assessment dependencies | Inventory representative content calls; bind required operations to attempt and actor. Deny unrelated data/features; retain service authorization for actual background processing |

External-provider capability and SEB allowlist behavior cannot be established by source inspection. They are explicit integration deliverables, not claims of Phase 1 completion. Neither basic nor adaptive support may be removed to avoid them.

## 5. Batch and interface decisions

### Bounded request handling

Observed: `lib/oli_web/endpoint.ex` sets parser body `length: 512_000_000`; this is a byte limit, not an identifier-count limit. `AttemptController.bulk_retrieve`, nested `partInputs`/`evaluations`, and `ActivityController.bulk_retrieve_delivery` show no explicit item-count cap. `state/intrinsic.ts` submits arrays as supplied; adaptive deck builds a list from its selected activity mapping without chunking.

Implementation contract (Phases 3/5):

- Cap read batches at **100 identifiers** (`attemptGuids` and delivery `resourceIds`), measured on raw input before deduplication. Update adaptive read callers to chunk into at most 100 and combine results before rendering; no partial render on failed chunk. Authorization is all-or-none within each HTTP request; chunking does not create a cross-request snapshot guarantee.
- Cap mutation arrays at **1,000 entries per request** (`partInputs`, client evaluations). Do not chunk a logical submission: reject oversized input before lookup or writes. This allows large multipart activities while bounding work; add 1,000/1,001 boundary fixtures and validate representative content before release.
- Cap explicit state projection key lists/upsert maps at **100 top-level keys**; omit-key secure reads mean the server-owned manifest, never all global state. Attempt snapshots remain bounded by existing body handling and server-owned shape, not an arbitrary global key projection.
- Preserve existing upload/body limits in this phase; a 512 MB parser allowance is not a reason to allocate unbounded authorization collections. Return stable JSON invalid/oversized-request errors before queries; avoid string-to-atom conversion.
- Malformed inputs, duplicate mutation GUIDs, unresolved IDs and mismatched parents fail the entire operation. Read duplicates may be normalized only after the raw-count check; match the complete unique requested/resolved sets. Resolve with bounded set-based joins, not one query per part.
- Limits above are new selected defaults, not measurements of maximum production content. Phase 5/7 compatibility fixtures are mandatory; revise the documented bounded value if representative content demonstrates a need, never silently truncate or exempt an endpoint.

Existing `save_part` ignores its activity parent parameter, and `save_activity` maps all body part GUIDs independently of the URL activity. These are explicit resolver regression cases. The read serializer currently selects the activity model; ordinary finalized review needs a feedback-policy-aware projection, not permission to return the unmodified delivery model.

### Provider-neutral contracts

Use FDD section 5 function signatures and tagged outcomes. Define types and tests before wiring transports:

- Admission: verified canonical `user_id`, `section_id`, `resource_id`; optional bounded provider label for diagnostics. Produced only by trusted adapter code, never reconstructed from client flags or latest saved LTI claims.
- Scope: immutable `{section_id, resource_id}` on the current session row. Neither attempt state nor provider-specific fields are required. Both null means ordinary; a malformed pair means invalid credential, never ordinary fallback.
- Target: canonical section/page, owning user, resource/activity/part attempt IDs as applicable, pinned revision and lifecycle state. For a batch, resolve and authorize all members before execution.
- Closed operations: `:prologue`, `:deliver`, `:start`, `:save`, `:submit`, `:review`, `:dependency_read`, `:dependency_write`, `:authentication`, `:exit`. Server dispatch selects operation; review is not a request flag that downgrades a write.
- Access modes: `:ordinary_delivery`, `:secure_delivery`, `:review`; review mode does not remove current scope. Only finalized owned attempts satisfying ReviewPolicy and feedback visibility qualify for ordinary review.
- `Accounts.get_user_session/1` returns exact valid token record identity, user and optional scope; keep existing user-only lookup compatible. Only secure signed socket payload contains record identity, never a raw cookie token or unsigned capability.
- Error contract: unauthenticated/expired retains existing 401/login behavior; policy denial uses 403 and bounded reason; unresolved/foreign identity retains non-disclosing not-found behavior. Admission failure cannot revoke other tokens.

## 6. Verification ownership and reusable harness design

Planned names in matrices are test-case contracts, not tests already added. Extend existing suites where possible:

| Key | Existing suite or proposed owner | Phase |
| --- | --- | --- |
| LTI | `test/oli_web/lti_redirect_test.exs`, `test/oli_web/controllers/lti_controller_test.exs`, `test/oli/lti/secure_launch_test.exs` | 4 |
| AUTH | `test/oli_web/user_auth_test.exs`; new `test/oli/accounts/secure_session_test.exs` | 2/4 |
| WEB | New `test/oli_web/secure_assessment_authorization_test.exs`; extend existing prologue/lesson/page controller suites | 3/5 |
| API | `test/oli_web/controllers/api/attempt_controller_test.exs` plus WEB matrix | 3 |
| LIFECYCLE | `test/oli_web/controllers/api/page_lifecycle_controller_test.exs`, `test/oli/delivery/attempts/page_lifecycle_test.exs` | 3/6 |
| MODEL | `test/oli_web/controllers/activity_controller_test.exs` plus WEB matrix for pinned activity membership | 3/5 |
| STATE | Existing `test/oli_web/controllers/api/{resource_attempt_state,global_state,section_state,blob_storage}_controller_test.exs` | 3/5 |
| REVIEW | `test/oli_web/live/delivery/student/review_live_test.exs`, page delivery controller tests | 3/5 |
| SOCKET | New `test/oli_web/channels/secure_assessment_test.exs`, reuse `test/support/channel_case.ex` | 3/4 |
| EMBED | `test/oli_web/controllers/legacy_superactivity_controller_test.exs` | 3/5 |
| TOOL | Existing API LTI controller/integration tests, `test/oli_web/controllers/lti_ags_controller_test.exs`, `test/scenarios/lti_external_tool/` examples | 5/6/7 |
| SHELL | New focused `secureDelivery` Jest suites in existing delivery test layout; basic LiveView DOM/payload assertions | 5 |
| ISOLATION | New `test/oli_web/secure_assessment_isolation_test.exs`; real scenarios under `test/scenarios/delivery/secure_assessment/` | 6 |

Design a test-only `SecureAssessmentHelpers` module in Phase 2/3, not an application abstraction:

1. Create N and S as separate `build_conn`/cookie jars with distinct real token records for the same user. Never recycle S's cookie response into N. Use actual login/admission for integration tests; lower-level injected scoped rows are appropriate only for policy unit tests.
2. Keep independent connected LiveViews and channels. Use shared SQL sandbox ownership for spawned processes, following ChannelCase; do not use process sleeps to assert disconnection. Subscribe to exact token topics and assert N receives no disconnect when S exits.
3. `snapshot_ordinary_access(N)` captures route status, authorized content and writable ordinary-page behavior before/after S lifecycle transitions. Include N's permitted protected review and its continued denial of protected delivery; do not equate independence with bypassing resource policy.
4. Retain S's row for deliberate orphan cases. Expire/delete only S by exact ID for lifecycle cases. Create S2 without revoking S/N; check same/different sections, same deployment, stale secure cookie on fresh ordinary entry and former selector enabled.
5. Observe no side effects on denial: attempt counts/answers/state/files/grade jobs unchanged. Match expected structured telemetry without credentials/answers/identity labels. Capture intentional logs rather than suppressing startup infrastructure errors.
6. Keep scenario domain setup real (author/publish/section/enroll/attempt directives). Use `build_scenario` and, only if required, `extend_scenario` during Phase 6. Do not implement speculative scenario directives in Phase 1.

Representative content contracts: A is a graded basic multipart assessment with traditional and one-at-a-time variants, timer/untimed variants and delayed feedback; B is graded adaptive content with nested/banked screens, stateful resume, EverApp values and both blob providers; C is an ordinary page in the same section; D is in another enrolled section. Add uploads/media, an embedded superactivity and an external LTI tool with genuine review behavior. Seed wrong-user/parent IDs and a publication update while an attempt remains pinned. All renderer variants must be tested in delivery, secure review and ordinary review.

## 7. Baseline and gate evidence

Executed on 2026-09-22, before any application changes for this phase:

```sh
mix test test/oli_web/lti_redirect_test.exs test/oli_web/user_auth_test.exs test/oli_web/controllers/api/attempt_controller_test.exs test/oli_web/live/delivery/student/review_live_test.exs test/oli/delivery/sections/assessment_settings_test.exs
```

Result: **69 tests, 0 failures**, ExUnit seed 667447. The test alias initialized/migrated the test database. Startup emitted an analytics backfill inventory-recovery `DBConnection.OwnershipError` from `Oli.Application.safe_inventory_recovery/0`, as well as seed/startup logs; this occurred without Phase 1 application changes and did not fail tests. It is not evidence of a secure-assessment failure and was not hidden or fixed out of scope.

G1 establishes an inspected boundary matrix, selected bounded defaults, interface contracts and named planned checks. It does not establish current enforcement or external-provider/SEB compatibility. Phases 3/5 must reconcile the matrix against any newly added routes/callers; Phase 7 retains real integration evidence before enablement. Requirements remain `verified_plan` with no implementation proofs claimed by this inventory.

## 8. Phase 3 enforcement reconciliation

- B03–B11 and B13 run the shared page/attempt policy before context construction,
  redirects or mutation. Controller action and router LiveView metadata select the
  operation. Query/body parameters cannot turn prologue/delivery into review.
- B12/B17/B19 model, tool-launch, report and discussion dependencies deny protected
  access without an assessment-bound adapter. Membership checks include the
  current page projection and persisted dynamic/pinned activity attempts.
- B15 resolves known resource-attempt blob keys. Unresolved legacy ordinary keys
  retain their existing semantics; secure tokens never get that fallback. User
  blob namespaces and global/section state remain denied for scoped tokens until
  the Phase 5 projection adapters are implemented.
- B16 resolves real activity attempts first. Only ordinary credentials may use a
  server-created preview capability, still subject to the controller's existing
  actor/author ownership check. A mixed author/secure cookie does not get a preview
  exemption. B18 retains its independent service authentication.
- Connected prologue/lesson/review hooks revalidate mount, navigation, events,
  asynchronous results and messages. One-at-a-time component callbacks have their
  own guard. Canonical score notifications remain usable. Unscoped outline and
  embedded assistant/support/system-message surfaces are not mounted for secure
  delivery. Page-scoped ordinary assistant callbacks also recheck current policy.
- All four existing user-socket channel families deny secure credentials. Ordinary
  channel ownership/enrollment and protected discussion policy are checked before
  joins, deferred reads and outbound messages. Phase 5 must add explicit scoped
  dependency adapters if a renderer needs these subscriptions; there is no blanket
  global/section channel exemption.
- Finalized secure attempts cannot use active-delivery data/write endpoints.
  Explicit page review retains ReviewPolicy/feedback checks. Finalized dependency
  reads require the Phase 5 review adapters, not merely a client REVIEW flag.

Production admission, current-token explicit exit/disconnect integration, full
assessment-only UI and full renderer/dependency review remain Phases 4–5. This
reconciliation does not authorize feature enablement or exclude any required page
type. The complete two-computer/AGS and real SEB matrices remain Phases 6–7.

## Decision Log

### 2026-09-23 — Native assessment activity scope

- Change: LTI activities and superactivities embedded in assessments are excluded. Earlier provider-adapter inventory entries are historical, not remaining implementation or release requirements.
- Reason: Explicit user scope clarification; retain both basic/adaptive pages, read-only review guards and existing feedback filtering.
- Evidence: `docs/exec-plans/current/secure-assessment/phase-5-execution.md` and AC-024 in `docs/exec-plans/current/secure-assessment/requirements.yml`.
- Impact: Phase 5 covers native assessment rendering/state/models/media/uploads. Moodle LTI admission and LMS grade passback are unchanged; excluded activity routes gain no secure-session exemption.
