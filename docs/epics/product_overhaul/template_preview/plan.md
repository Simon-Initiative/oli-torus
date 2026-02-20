# Template Preview — Delivery Plan

Scope and guardrails reference:
- PRD: `docs/epics/product_overhaul/template_preview/prd.md`
- FDD: `docs/epics/product_overhaul/template_preview/fdd.md`

## Scope
Deliver template preview from Template Overview by reusing canonical student delivery routes. The flow must authorize template access, ensure idempotent learner enrollment for the acting user, and open `/sections/:section_slug` in a new tab with deterministic error handling and telemetry.

## Non-Functional Guardrails
- Preview launch-preparation latency target: p95 <= 700ms under normal authoring load.
- Enrollment idempotency target: zero duplicate enrollments for `(user_id, section_id)` from preview flow.
- Security/tenancy: server-side authz and tenant-scoped section resolution before any enrollment mutation.
- Accessibility: Preview action and status/error feedback remain WCAG 2.1 AA compliant.
- Observability: emit preview request/enrollment outcome/success/failure telemetry with ID-only metadata.
- Rollout posture: no feature flag; release only after regression and operational gates pass.

## Clarifications & Default Assumptions
- `current_user` is available for template authors/admins in the Template Overview LiveView session; if absent, flow returns deterministic `:missing_delivery_identity` without DB writes.
- V1 launch destination is always canonical student home (`/sections/:section_slug`) and does not deep-link to previously visited pages.
- Browser popup-blocks are treated as client launch failures; backend enrollment work is not retried solely because popup dispatch failed.
- Existing enrollment uniqueness constraints (`enrollments.user_id+section_id` and enrollment-role uniqueness) are present in all deployed environments.

## Requirements Traceability
- Source of truth: `docs/epics/product_overhaul/template_preview/requirements.yml`
- Plan verification command:
  - `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py docs/epics/product_overhaul/template_preview --action verify_plan`
- Stage gate command:
  - `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py docs/epics/product_overhaul/template_preview --action master_validate --stage plan_present`

## Phase 1: Entry Point, Authorization, and UX Wiring
- Goal: Add a Preview control in Template Overview with strict authorization-gated visibility and accessible in-flight/error states.
- Tasks:
  - [ ] Add Preview action wiring in `OliWeb.Products.Details.Actions` and event handling in `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive`.
  - [ ] Gate rendering and event acceptance by existing template-management authorization checks from mounted context.
  - [ ] Add launch-in-progress disable state and deterministic error presentation (`preview_launching?`, `preview_error`) with localizable strings.
  - [ ] Ensure keyboard activation, accessible naming, and predictable focus continuity after success/failure.
  - [ ] Add server-side denial handling for direct unauthorized event invocation (not only hidden UI).
- Testing Tasks:
  - [ ] Add/extend LiveView tests for visibility, unauthorized denial, in-flight disabled behavior, and error-state rendering.
  - [ ] Add accessibility assertions for button semantics and status feedback behavior in the LiveView test coverage.
  - [ ] Command(s): `mix test test/oli_web/live/workspaces/course_author/products/details_live_test.exs`
- Definition of Done:
  - Preview action appears only for authorized template managers.
  - Unauthorized users cannot execute preview via forged event.
  - In-flight and error UX behavior is covered by passing LiveView tests.
- Gate:
  - Phase 1 tests pass and authorization regression risk is closed before backend orchestration is merged.
- Dependencies:
  - None.
- Parallelizable Work:
  - i18n copy additions and a11y polish can proceed in parallel with test-writing because they touch UI strings/templates without altering core backend behavior.

## Phase 2: Backend Launch Preparation Service and Enrollment Idempotency
- Goal: Implement deterministic `prepare_launch` orchestration with tenant-safe section validation and idempotent student enrollment ensure.
- Tasks:
  - [ ] Implement `Oli.Delivery.TemplatePreview.prepare_launch/3` with typed outcomes (`{:ok, %{section_slug, enrollment_outcome}} | {:error, reason}`).
  - [ ] Add/extend `Oli.Delivery.Sections.ensure_student_enrollment/2` for create/reuse/reactivate semantics inside a transaction.
  - [ ] Enforce tenant and section-type checks before enrollment writes; reject invalid/unavailable sections early.
  - [ ] Ensure role-association upsert uses conflict-safe semantics to prevent duplicate role rows.
  - [ ] Return launch data only after successful enrollment ensure; never construct router URLs inside delivery context.
- Testing Tasks:
  - [ ] Add unit tests for `TemplatePreview.prepare_launch/3` success, unauthorized, section unavailable, and missing identity cases.
  - [ ] Add enrollment helper tests covering create, reuse, suspended-to-enrolled reactivation, and duplicate-call idempotency.
  - [ ] Add concurrency-focused regression test proving repeated preview requests do not create duplicate enrollment/role rows.
  - [ ] Command(s): `mix test test/oli/delivery/template_preview_test.exs test/oli/delivery/sections_test.exs`
- Definition of Done:
  - Backend service returns deterministic typed outcomes for all expected branches.
  - Enrollment idempotency and transactional integrity are validated by automated tests.
  - Tenant/authz preconditions are enforced before mutation paths.
- Gate:
  - All Phase 2 tests pass with no duplicate-enrollment regressions under repeated invocations.
- Dependencies:
  - Phase 1 event contract and state naming for invocation path.
- Parallelizable Work:
  - Service-level tests and enrollment helper implementation can run in parallel once interface contract is agreed, because one validates orchestration boundaries while the other focuses persistence semantics.

## Phase 3: LiveView Launch Integration and Failure UX Completion
- Goal: Connect LiveView preview event to backend service and open canonical student home in a new tab with robust fallback/error behavior.
- Tasks:
  - [ ] Wire `"template_preview"` event flow to call `TemplatePreview.prepare_launch/3` and translate outcomes to UI state.
  - [ ] Build launch path in LiveView with canonical router path (`~p"/sections/#{section_slug}"`) and trigger client new-tab dispatch.
  - [ ] Ensure no blank-window behavior on backend error by only dispatching launch after successful preparation.
  - [ ] Provide deterministic popup-block/client-launch failure messaging with manual fallback link behavior.
  - [ ] Confirm originating authoring tab retains context and recovers action state after launch attempt.
- Testing Tasks:
  - [ ] Add/extend LiveView integration tests for first-launch (create enrollment), repeat-launch (reuse), and failure flows.
  - [ ] Add tests ensuring canonical destination path generation and no launch dispatch on service error.
  - [ ] Command(s): `mix test test/oli_web/live/workspaces/course_author/products/details_live_test.exs`
- Definition of Done:
  - Authorized preview clicks open canonical student home on success.
  - Failure flows show deterministic feedback and avoid duplicate writes/blank launch behavior.
  - Integration tests validate create vs reuse outcomes and launch path correctness.
- Gate:
  - End-to-end preview flow works in LiveView tests for both happy and failure paths.
- Dependencies:
  - Phase 2 service and enrollment semantics completed.
- Parallelizable Work:
  - Popup-fallback UI copy/localization and test assertions can run parallel to launch wiring since they depend only on exposed error states.

## Phase 4: Observability, Performance Verification, and Operational Hardening
- Goal: Add telemetry/AppSignal visibility and prove non-functional targets for reliability, latency, and secure metadata.
- Tasks:
  - [ ] Emit telemetry events for requested, enrollment ensured (`created|reused`), launch succeeded, and launch failed.
  - [ ] Add AppSignal tags/labels for `template_preview` outcome categories and latency buckets.
  - [ ] Ensure metadata uses IDs/category values only (no sensitive payload logging).
  - [ ] Add timing instrumentation around prepare-launch path and verify p95 against <= 700ms target in representative environment.
  - [ ] Document alert thresholds and release monitoring checks for failure-rate and latency regressions.
- Testing Tasks:
  - [ ] Add telemetry tests asserting event emission sequence and required metadata fields.
  - [ ] Add regression test for failure telemetry categorization without PII-bearing payload values.
  - [ ] Run focused suites plus broad regression sweep.
  - [ ] Command(s): `mix test test/oli/delivery/template_preview_test.exs test/oli_web/live/workspaces/course_author/products/details_live_test.exs && mix test`
- Definition of Done:
  - Telemetry and AppSignal signals are emitted for full lifecycle and validated by tests.
  - Performance verification evidence shows launch-prep path meets or explains p95 target.
  - Operational thresholds and on-call monitoring expectations are documented.
- Gate:
  - Observability and performance checks are complete and acceptable for release sign-off.
- Dependencies:
  - Phase 3 end-to-end flow stabilized.
- Parallelizable Work:
  - AppSignal dashboard/alert configuration can proceed in parallel with telemetry unit tests because runtime wiring and monitoring configuration are separable workstreams.

## Phase 5: Final Regression, Documentation, and Release Readiness
- Goal: Complete release gate with full regression confidence, documentation alignment, and rollback posture.
- Tasks:
  - [ ] Run full automated regression and fix any preview-related breakages before merge.
  - [ ] Execute manual QA matrix from PRD: first launch create, repeat launch reuse, unauthorized denial, keyboard/focus behavior, popup-block fallback.
  - [ ] Update feature documentation/changelog notes for template preview behavior and known limitations.
  - [ ] Confirm rollback posture: additive code-path changes only, no schema migrations, revert-by-deploy available.
  - [ ] Capture final acceptance traceability for FR-001..FR-008 and AC-001..AC-007.
- Testing Tasks:
  - [ ] Run full backend suite and targeted UI regressions used by template overview flows.
  - [ ] Command(s): `mix test`
- Definition of Done:
  - All required automated and manual checks pass with no unresolved critical defects.
  - Documentation and acceptance mapping are complete.
  - Release/rollback notes are explicit and ready for deployment handoff.
- Gate:
  - Product + engineering sign-off on acceptance criteria and non-functional readiness.
- Dependencies:
  - Phases 1-4 complete.
- Parallelizable Work:
  - Documentation updates and acceptance-traceability write-up can proceed while full regression is executing.

## Parallelisation Notes
- Phase 1 must complete first to lock event contract and authorization behavior.
- Within Phase 2, orchestration-service tests and enrollment-helper implementation/testing can proceed in parallel after interface agreement.
- Phase 3 starts after Phase 2 gate; popup-fallback UX and localization can run concurrently with launch dispatch wiring.
- Phase 4 instrumentation work can begin once Phase 3 behavior is stable; monitoring/dashboard setup can run parallel to telemetry tests.
- Phase 5 documentation and traceability are parallelizable with final regression execution, but release sign-off waits for all prior phase gates.

## Phase Gate Summary
- Gate A (post Phase 1): Authorization-gated Preview UI/event behavior verified; safe to proceed with backend orchestration.
- Gate B (post Phase 2): Idempotent enrollment ensure and tenant-safe launch preparation validated.
- Gate C (post Phase 3): End-to-end launch and deterministic failure UX proven in integration tests.
- Gate D (post Phase 4): Observability, performance, and security-metadata checks meet non-functional requirements.
- Gate E (post Phase 5): Full regression, documentation, and acceptance sign-off complete for release.
