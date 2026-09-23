# Secure Assessment — Delivery Plan

## Scope

Implement the session-only secure-assessment design, including section settings, provider-neutral admission, server authorization, basic/adaptive delivery and review, and operational verification.

Source artifacts:

- PRD: `docs/exec-plans/current/secure-assessment/prd.md`
- FDD: `docs/exec-plans/current/secure-assessment/fdd.md`
- Governing decisions: `docs/exec-plans/current/secure-assessment/constrain.md`
- Canonical acceptance: `docs/exec-plans/current/secure-assessment/requirements.yml`

Guardrails: no account-wide restriction, no active-assessment registry, no browser-close dependency, no student exceptions, and no additional replay/diagnostic-bypass mechanisms. Implement the current-token design in the FDD, not the superseded account-wide proposal. An ordinary credential can access ordinary course content while another secure credential exists; a protected assessment still requires secure admission except for eligible finalized read-only review.

## Clarifications & Default Assumptions

- `secure_delivery` is a non-null SectionResource boolean defaulting false. `SUPPORTS_SECURE_DELIVERY` is runtime environment configuration, default false, with restart rather than recompilation required.
- Capability remains false on serving instances until every phase gate passes and all serving nodes enforce scope. Tests may enable it locally. Intermediate commits are not independently feature-ready.
- Scope lives only on the presented `users_tokens` row. Ordinary entry must never inspect another token, lock an account, or revoke/disconnect another session. Browser close may leave a token behind without affecting other launches.
- Initial verification is Moodle/SEB direct-resource LTI. The common admission and policy interfaces remain provider-neutral; Respondus implementation is excluded.
- Basic traditional, basic one-at-a-time, adaptive delivery, secure review and ordinary eligible review are mandatory. Required dependencies are implementation work, not grounds for excluding a page type.
- Retain existing authentication expiry and attempt deadlines. No inactivity unlock, heartbeat, support-release process, new reauthentication lifetime, or finish-before-exit rule is needed.
- Phase 1 resolves endpoint limits and dependency inventory from real callers. Pilot versions/content are recorded before final acceptance. Link a Jira issue when supplied; no external issue creation is assumed.
- Commands below run from repository root unless stated otherwise. New test paths are explicitly identified. Run Mix commands with scoped escalated permissions per `AGENTS.md`. Migration rollback runs only against a disposable test database.
- Checked tasks and implementation proof are recorded during development, not inferred from this plan. Keep acceptance proof lists empty until evidence exists.

## Phase 1: Inventory boundaries and establish verification contracts

Status: complete. Evidence: `docs/exec-plans/current/secure-assessment/design/boundaries.md` and `docs/exec-plans/current/secure-assessment/phase-1-execution.md`. Baseline: 69 tests, 0 failures; no application implementation claimed.

- Goal: Make every entry, protected operation and required dependency accountable before authorization changes.
- Tasks:
  - [x] Record a route/operation matrix in `docs/exec-plans/current/secure-assessment/design/boundaries.md`: router pipelines, legacy aliases, LTI destinations, page context creation, attempt APIs, LiveView mounts/events/components/async handlers, channel joins and outbound messages.
  - [x] Trace basic and adaptive clients through state, models, uploads/media, dynamic activities, superactivity and external-tool launch/return/review. Identify canonical parent assessment/attempt and read/write operation for each dependency.
  - [x] Record existing batch limits; choose finite limits for unbounded endpoints based on actual callers. Identify all-before-mutation checks and mismatched parent GUID cases.
  - [x] Specify Admission/Scope/Target contracts and the closed operation vocabulary from FDD section 5. Keep verifier-specific claims outside generic policy interfaces.
  - [x] Design independent-cookie HTTP/LiveView/channel test helpers and representative basic/adaptive content. Inventory existing tests before adding overlapping coverage.
- Testing Tasks:
  - [x] Establish baseline results for settings, launch redirects, authentication, attempts and student review; distinguish pre-existing failures.
  - [x] Confirm each inventoried boundary has a named planned test and that external-provider review dependencies are represented.
  - Command(s): `mix test test/oli_web/lti_redirect_test.exs test/oli_web/user_auth_test.exs test/oli_web/controllers/api/attempt_controller_test.exs test/oli_web/live/delivery/student/review_live_test.exs`
- Definition of Done:
  - Boundary/dependency matrix names implementation targets, operation owners, batch limits and tests; no required renderer dependency is silently exempted.
- Gate:
  - G1: Every identified student entry and protected data path is classified; remaining external integration work has explicit Phase 5 tasks and Phase 7 evidence requirements.
- Dependencies:
  - None; PRD/FDD and agreed confinement decisions are the inputs.
- Parallelizable Work:
  - Endpoint inventory and representative content/dependency inventory can proceed independently, then reconcile one canonical matrix.

## Phase 2: Persist settings and current-token scope

Status: complete. Evidence: `docs/exec-plans/current/secure-assessment/phase-2-execution.md`. G2 passed; capability defaults false and production enablement remains gated by later phases.

- Goal: Add backward-compatible storage and runtime configuration without activating secure delivery.
- Tasks:
  - [x] Generate `add_secure_delivery_to_section_resources` and `add_secure_assessment_scope_to_users_tokens` migrations using `mix ecto.gen.migration`; implement explicit `up/0` and `down/0`.
  - [x] Add nullable scope FKs/indexes and the both-null-or-session-with-both-present constraint. Target deletion revokes scoped rows, never nulls their scope. Down migration deletes only scoped rows before removing scope columns.
  - [x] Extend SectionResource, Combined and settings casting/combination; do not add Revision or StudentException fields. Validate authoritative graded-resource status.
  - [x] Parse runtime capability with the existing boolean helper. Add context-level checks to updates, bulk/copy and audit paths; reject incompatible copies atomically and preserve section overrides during publication refresh.
  - [x] Add the conditional Secure Delivery column using existing Assessment Settings patterns. Unsupported ordinary edits omit this key; explicit enabling is rejected server-side.
  - [x] Add immutable scoped-token issuance and current-session projection while preserving user-only lookup compatibility. Reject malformed scope; no user-wide uniqueness or token search.
- Testing Tasks:
  - [x] Cover defaults, true/false/unset configuration, restart behavior, graded validation, authorization, column presence/absence, forged enabling, bulk/copy/audit and refresh preservation.
  - [x] Test atomic scope insertion, malformed pairs, ordinary existing tokens, concurrent independent scopes and deletion behavior. Create `test/oli/accounts/secure_session_test.exs`.
  - [x] Verify migration up/down/up on disposable data containing both ordinary and scoped tokens; ordinary rows must survive rollback.
  - Command(s): `mix test test/oli/delivery/sections/assessment_settings_test.exs test/oli_web/live/sections/assessment_settings/settings_live_test.exs test/scenarios/delivery/assessment_settings/assessment_settings_test.exs test/oli/accounts/secure_session_test.exs`
  - Migration commands, in the disposable database: `MIX_ENV=test mix ecto.migrate`, `MIX_ENV=test mix ecto.rollback -n 2`, `MIX_ENV=test mix ecto.migrate`.
- Definition of Done:
  - Settings and token representations meet the FDD, preserve existing rows and expose no account-wide state. Migration reversibility has recorded evidence.
- Gate:
  - G2: Storage/configuration/settings tests pass; capability remains disabled outside isolated tests.
- Dependencies:
  - Phase 1 contracts and boundary inventory.
- Parallelizable Work:
  - Settings UI/context and token persistence may proceed separately after agreeing migration ownership and shared scope types.

## Phase 3: Enforce shared authorization across transports

Status: complete. Evidence: `docs/exec-plans/current/secure-assessment/phase-3-execution.md`. G3 passed with fail-closed dependency boundaries; production admission and full dependency/rendering support remain gated by Phases 4–5.

- Goal: Make scoped and ordinary protected-resource requests safe before adding production admission.
- Tasks:
  - [x] Implement `Oli.Delivery.SecureAssessments` target resolution, session-scope and resource-policy checks. Resolve real attempt ownership, pinned revisions and supplied parent relationships; reject complete batches before any result or mutation.
  - [x] Extend UserAuth and add thin HTTP/LiveView scope adapters. Check before redirect/context construction, including legacy aliases and index navigation; authentication/assets/exit remain narrowly available.
  - [x] Apply checks to controller/API actions and LiveView event, component, asynchronous and navigation paths identified in Phase 1. Revalidate connected credentials and current resource policy at execution.
  - [x] Add versioned signed secure socket capabilities backed by the exact token row. Enforce join, delayed read and outbound authorization; ordinary legacy credentials confer no protected-delivery entitlement.
  - [x] Deny unrelated/global subscriptions for secure tokens; add assessment-scoped subscriptions only where inventory requires them. Keep service callbacks independently authenticated.
  - [x] Add typed JSON denials and safe HTML explanations; preserve normal unauthenticated/not-found behavior. Avoid redirect loops, sensitive response caching and cached authorization across events.
  - [x] Add bounded denial telemetry and set-based ownership queries; enforce batch limits before resolution.
- Testing Tasks:
  - [x] Create `test/oli_web/secure_assessment_authorization_test.exs` covering the inventory matrix with ordinary and injected scoped tokens, including staff/preview mixed-cookie paths.
  - [x] Test wrong page/section/actor, mismatched GUID parents, mixed batches with zero side effects, expired/deleted token reconnect, missed disconnect and protected outbound data.
  - [x] Verify ordinary fast paths do not query other user sessions; measure representative batch query counts and assert telemetry privacy.
  - Command(s): `mix test test/oli_web/secure_assessment_authorization_test.exs test/oli_web/controllers/api/attempt_controller_test.exs test/oli_web/controllers/api/resource_attempt_state_controller_test.exs test/oli_web/controllers/page_delivery_controller_test.exs`
- Definition of Done:
  - All inventoried transports invoke the common policy before protected work; no UI flag, enrollment, opaque GUID or ordinary socket credential bypasses it.
- Gate:
  - G3: Route/API/event/channel negative tests pass, including all-or-none batches and ordinary-session noninterference. Dependency adapters still under construction cannot be broadly exempted.
- Dependencies:
  - Phases 1 and 2.
- Parallelizable Work:
  - HTTP/API, LiveView and channel adapters can proceed independently against the same resolver contracts and shared negative fixtures.

## Phase 4: Wire trusted admission and independent session lifecycle

- Goal: Issue scope only from verified current entry while keeping ordinary launches independent.
- Tasks:
  - [x] Share structured LTI target resolution between `OliWeb.LtiRedirect` and admission. Resolve the incoming revision-slug resource identifier to canonical section/resource; never use latest stored launch parameters as authority.
  - [x] Adapt `Oli.Lti.SecureLaunch` evidence into provider-neutral admission after existing LTI signature/state/nonce/registration/deployment checks. Recheck graded policy/capability and selected resource during scoped-token insertion; install cookie only after persistence succeeds.
  - [x] Remove the deployment-wide `TORUS_SEB_REQUIRED_LAUNCHES` ordinary-launch gate and obsolete enforcement configuration. Preserve existing assertion freshness and validation, without adding excluded mechanisms.
  - [x] Allow validated ordinary entry even with a stale secure cookie; issue an ordinary token without querying/revoking/disconnecting other sessions. Add generic admission contract tests separately from real LTI adapter tests.
  - [x] Preserve current-token scope through reload/reconnect and retain existing expiry. Disable secure remember-me issuance and clear only the current browser remember-me cookie.
  - [x] Implement CSRF-protected, idempotent current-token exit at any attempt state; publish only token-specific disconnects after deletion. No finalization dependency, browser-close callback or support release.
  - [x] Emit bounded admission/explicit-exit telemetry without raw claims, token values or invented close events.
- Testing Tasks:
  - [x] Test exact/missing/mismatched target and evidence, concurrent admission/settings changes, persistence failure, expired credentials and partial scope failure.
  - [x] Test ordinary launch with stale secure cookie and former broad selector configured; retain other ordinary/secure HTTP, LiveView and channel connections.
  - [x] Test logout before/after submission, repeat logout, saved unfinished attempts and no cleanup callback; assert no secret appears in exit URLs/logs.
  - Command(s): `mix test test/oli/lti/secure_launch_test.exs test/oli_web/controllers/lti_controller_test.exs test/oli_web/lti_redirect_test.exs test/oli_web/user_auth_test.exs test/oli/accounts/secure_session_test.exs test/oli_web/secure_assessment_authorization_test.exs`
- Definition of Done:
  - Trusted current entry alone determines a new token's scope; secure entry and exit cannot mutate another session's authority.
- Gate:
  - G4: Passed. Admission and lifecycle matrix passes; ordinary course launch remains functional with stale, live and orphaned secure credentials. See `phase-4-execution.md` (361 tests, 0 failures; 39 existing exclusions).
- Dependencies:
  - Phases 2 and 3; no admission enabled before enforcement exists.
- Parallelizable Work:
  - Adapter/redirect tests and logout/reconnect tests may proceed separately after current-session projection is stable.

## Phase 5: Complete delivery shells, review and dependency adapters

- Status: **Complete; G5 passed for the confirmed native-activity scope.** Evidence and remaining rollout gates: `docs/exec-plans/current/secure-assessment/phase-5-execution.md`. Phase 6 may proceed; production enablement still requires Phase 7.
- Goal: Support every required renderer and assessment dependency without weakening confinement.
- Tasks:
  - [x] Add server-derived secure mode to basic/legacy/adaptive rendering; remove unrelated navigation from both DOM and serialized URL/data payloads. Preserve internal question/screen navigation, accessibility, timers, submit, review and exit.
  - [x] Wire adaptive page store, deck layout and adaptivity actions to secure mode and existing REVIEW context. Suppress persistence/evaluation effects in review; server authorization remains definitive.
  - [x] Authorize finalized submitted/evaluated review by ownership plus existing ReviewPolicy/feedback rules before context construction. Allow ordinary eligible review independently of another secure token; deny retry/writes without appropriate admission.
  - [x] Complete every Phase 1 dependency adapter: attempt-owned state, legacy blob mapping, model/media/upload authorization, dynamic activities. LTI activities and superactivities are excluded by the confirmed scope. Genuine shared reads use narrow server-owned projections; no global-state exemption or blanket empty-namespace remapping.
  - [x] Verify native media/upload ownership and public-asset behavior against the parent-attempt/read-only contract. Keep excluded LTI activity and superactivity routes denied to secure sessions.
  - [x] Render confined completion, denied-review and ordinary prerequisite/error states without loops or unrelated secure navigation. Apply existing accessible components and Tailwind conventions where appropriate.
- Testing Tasks:
  - [x] Cover traditional, one-at-a-time and adaptive delivery, secure review and ordinary review; test delayed feedback, answer/model redaction, pinned revisions and forged review flags.
  - [x] Test internal navigation without writes in review, dependency reads/writes, cross-assessment keys, dynamic membership and media/upload ownership.
  - [x] Add targeted adaptive Jest suites for secure navigation payloads and review side effects; check keyboard/focus/labels/reflow and narrow screens in Chrome (automated shell-level check; full SEB pilot remains Phase 7).
  - Command(s): `mix test test/oli_web/controllers/page_delivery_controller_test.exs test/oli_web/live/delivery/student/review_live_test.exs test/oli_web/secure_assessment_authorization_test.exs`
  - Frontend command from `assets/`: `yarn test --runInBand --testPathPattern=secureDelivery` (name new focused suites with `secureDelivery`).
- Definition of Done:
  - All renderer/mode combinations and required dependency adapters are implemented, with read-only review enforced on client and server.
- Gate:
  - G5: Renderer/dependency matrix passes; no unsupported required page type, broad API exception or feedback leak remains.
- Dependencies:
  - Phases 3 and 4; Phase 1 dependency inventory.
- Parallelizable Work:
  - Basic shell, adaptive shell and dependency adapters may proceed separately against stable operation/access-mode contracts; reconcile shared review serialization together.

## Phase 6: Prove isolation and end-to-end lifecycle compatibility

- Goal: Demonstrate the no-cross-session-lockout invariant and preserve normal assessment behavior.
- Tasks:
  - [ ] Add real publish/settings/copy/attempt workflows under `test/scenarios/delivery/secure_assessment/`, using `Oli.Scenarios` and the applicable scenario skills rather than fixture-built domain state.
  - [ ] Build independent-cookie S/N integration matrix: same learner, same/different section; S live, submitted, abandoned, expired, revoked, target-missing and deliberately orphaned. Compare N against its no-S baseline, including fresh launches and already-connected views/channels.
  - [ ] Verify reconnect/relaunch resumes saved work without timer reset, extra attempt or revocation of prior credentials. Exercise untimed abandonment and existing timed auto-submit.
  - [ ] Verify enrollment, gating, accommodations, grading and AGS across interleaved ordinary/secure launches, failure/retry and background callbacks. Correct a demonstrated service-binding defect at section/resource ownership, never by blocking ordinary entry.
  - [ ] Exercise capability/resource toggles, publication refresh and target deletion. Existing scopes remain scoped; capability off blocks only new admission/enabling and does not erase policy.
  - [ ] Inspect telemetry labels and sensitive responses, bounded batch behavior and query counts; retain sanitized implementation evidence mapped to acceptance IDs.
- Testing Tasks:
  - [ ] Create `test/oli_web/secure_assessment_isolation_test.exs` and `test/scenarios/delivery/secure_assessment/secure_assessment_test.exs` with the complete matrices above.
  - [ ] Repeat isolation using database-backed token reloads and application restart; include cross-node verification in the pilot when local tests cannot exercise cluster transport.
  - [ ] Run relevant existing suites, new suites and the full backend suite; capture intentional logs according to repository policy.
  - Command(s): `mix test test/oli_web/secure_assessment_isolation_test.exs test/scenarios/delivery/secure_assessment/secure_assessment_test.exs`, then `mix test`; from `assets/`: `yarn test --runInBand`.
- Definition of Done:
  - Retained automated evidence covers session isolation, renderer modes, attempts, review, grading and operational toggles without close signals or cleanup jobs.
- Gate:
  - G6: Any secure-state-induced change to N's otherwise-authorized ordinary access is release-blocking. All acceptance criteria have automated evidence or a specific Phase 7 manual check.
- Dependencies:
  - Phases 2–5.
- Parallelizable Work:
  - Isolation, scenario workflows, AGS integration and performance/privacy checks can run concurrently using separate test data and database isolation.

## Phase 7: Operational readiness, pilot and release gate

- Goal: Establish safe enablement and rollback with real Moodle/SEB evidence; this plan does not itself authorize a deployment.
- Tasks:
  - [ ] Update `docs/secure-torus-lti-spike.md` and feature operations documentation with runtime configuration, retired selector behavior, ordinary-review policy, dependency requirements and explicit browser-close limitations.
  - [ ] Document additive-schema-first deployment and require all serving nodes to enforce scope before capability enablement. Distinguish non-destructive capability disablement from downgrade.
  - [ ] Rehearse downgrade: stop new admissions, drain scoped connections, revoke only scoped tokens, then remove scope/policy schema under coordinated deployment. Preserve ordinary tokens; never deploy scope-ignorant nodes while scoped tokens remain usable.
  - [ ] Run representative Moodle/SEB pilot for both page types and both review modes, including save/reconnect, submission, early exit, close without logout, second-computer ordinary launch, scoped target denial and correct AGS placement. Record versions/configuration and sanitized evidence.
  - [ ] Run implementation review under `docs/CODEREVIEW.md`, always including security/performance and applicable Elixir/UI/TypeScript/requirements guidance. Resolve release-blocking findings and link supplied tracking information.
  - [ ] Reconcile PRD/FDD/plan only for verified implementation drift; record acceptance proofs without claiming unrun checks. Obtain operator approval for staged enablement.
- Testing Tasks:
  - [ ] Verify pilot SEB configuration allows required dependencies/internal navigation but does not rely on browser controls for server authorization. Verify native review behavior, ordinary concurrent access and token-specific disconnects across serving nodes.
  - [ ] Re-run migrations/rollback rehearsal on disposable data and all affected automated tests after fixes. Inspect captured evidence for tokens, raw claims, answers and sensitive exit parameters.
  - Command(s): `git diff --check`; rerun Phase 6 suites and the installed harness requirements master validator at the implementation-appropriate stage.
- Definition of Done:
  - Automated and manual acceptance evidence is retained, review findings resolved, and operational enablement/disablement/rollback procedures are executable.
- Gate:
  - G7: Release requires all preceding gates, both renderer/review pilots, cross-session isolation evidence and scope-aware nodes. Missing integration evidence blocks enablement rather than removing a page type or weakening policy.
- Dependencies:
  - Phase 6 and all earlier gates.
- Parallelizable Work:
  - Draft runbook and prepare pilot environments earlier; final review, rollback rehearsal and acceptance use the same release candidate.

## Requirements Coverage

Completion phases below own acceptance evidence; earlier phases provide implementation prerequisites. This table is planning traceability, not proof that the criteria already pass.

| Requirement | Acceptance criteria | Implementation phases | Completion gate |
| --- | --- | --- | --- |
| FR-001 | AC-001, AC-002 | 2 | G2 |
| FR-002 | AC-003, AC-004 | 2, 7 | G7 |
| FR-003 | AC-005, AC-006 | 2 | G2 |
| FR-004 | AC-007, AC-008, AC-009 | 2, 6 | G6 |
| FR-005 | AC-010, AC-011, AC-012, AC-013 | 3, 4, 5 | G5 |
| FR-006 | AC-014, AC-015, AC-016 | 2, 4, 6 | G6 |
| FR-007 | AC-017, AC-018, AC-019 | 3, 4, 6, 7 | G7 |
| FR-008 | AC-020, AC-021, AC-022 | 4, 6 | G6 |
| FR-009 | AC-023, AC-024, AC-025 | 3, 5, 6 | G6 |
| FR-010 | AC-026, AC-027, AC-028, AC-029 | 1, 3, 5 | G5 |
| FR-011 | AC-030, AC-031, AC-032 | 5, 7 | G7 |
| FR-012 | AC-033, AC-034 | 5, 6, 7 | G7 |
| FR-013 | AC-035, AC-036, AC-037 | 3, 5, 6 | G6 |
| FR-014 | AC-038, AC-039, AC-040 | 4, 6 | G6 |
| FR-015 | AC-041, AC-042 | 4, 6 | G6 |
| FR-016 | AC-043, AC-044, AC-045 | 4, 6, 7 | G7 |
| FR-017 | AC-046, AC-047, AC-048 | 3, 6, 7 | G7 |
| FR-018 | AC-049, AC-050, AC-051 | 2, 6, 7 | G7 |
| FR-019 | AC-052, AC-053 | 4 | G4 |
| FR-020 | AC-054, AC-055 | 6, 7 | G7 |
| FR-021 | AC-056, AC-057, AC-058 | 1, 2, 4 | G4 |
| FR-022 | AC-059, AC-060 | 3, 4, 6 | G6 |

## Parallelization Notes

- Main dependency chain: Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7. Independent work within a phase is listed above; overlapping preparation never waives a gate.
- Share one target resolver and current-session projection. Do not let transport or renderer work introduce separate admission state or competing policy logic.
- Settings/token schema work may be divided, but migration generation/order and rollback rehearsal need one coordinated owner. Parallel tests must use isolated data.
- Draft renderer branches, pilot content and runbooks while enforcement is being built; integration and activation wait for their dependencies.

## Phase Gate Summary

- G1: Complete boundary/dependency inventory and explicit test contracts.
- G2: Backward-compatible settings/token persistence and reversible migrations.
- G3: Shared HTTP/API/LiveView/channel authorization before protected work.
- G4: Verified admission and current-token-only lifecycle; ordinary launches remain independent.
- G5: All basic/adaptive delivery/review modes and narrow dependencies complete.
- G6: Automated isolation, lifecycle, grading and toggle matrices pass.
- G7: Reviewed release candidate, real Moodle/SEB evidence and safe operational rollout/rollback; only then enable capability.

## Decision Log

### 2026-09-23 — Native assessment activity scope

- Change: LTI activities and superactivities embedded in assessments are excluded. Earlier provider-adapter inventory entries are historical, not remaining implementation or release requirements.
- Reason: Explicit user scope clarification; retain both basic/adaptive pages, read-only review guards and existing feedback filtering.
- Evidence: `docs/exec-plans/current/secure-assessment/phase-5-execution.md` and AC-024 in `docs/exec-plans/current/secure-assessment/requirements.yml`.
- Impact: Phase 5 covers native assessment rendering/state/models/media/uploads. Moodle LTI admission and LMS grade passback are unchanged; excluded activity routes gain no secure-session exemption.
