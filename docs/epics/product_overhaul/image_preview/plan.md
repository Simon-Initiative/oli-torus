# Image Preview — Delivery Plan

Scope and guardrails reference:
- PRD: `docs/epics/product_overhaul/image_preview/prd.md`
- FDD: `docs/epics/product_overhaul/image_preview/fdd.md`

## Scope
Deliver template cover-image preview in `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive` for My Course, Course Picker, and Welcome by reusing canonical runtime rendering units (`course_card/1`, `CardListing.render/1`, `Intro.render/1`) with preview adapters and minimal preview-safe seams, plus authz-preserving access, telemetry, and parity verification.

## Non-Functional Guardrails
- Performance: initial preview render p95 <= 700ms; context switch p95 <= 400ms after initial load.
- Reliability: missing/invalid image data must degrade to canonical fallback without LiveView crashes.
- Security/authz: server-side permission boundaries remain unchanged; no preview controls for unauthorized users.
- Tenancy: preview data remains scoped to mounted template/product context; no cross-institution lookups.
- Data/storage: no schema migrations, backfills, or background jobs introduced.
- Caching: existing image delivery/caching path remains; no new cache invalidation behavior introduced.
- Observability: emit preview context selection/render outcome telemetry and AppSignal tags without PII.
- Accessibility/i18n: selector and preview region remain keyboard accessible, screen-reader meaningful, and localized.

## Clarifications & Default Assumptions
- The preview host is `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive` (default from FDD).
- Initial UX ships a single-context selector (not side-by-side context comparison).
- Placeholder policy for runtime-only dynamic fields (for example instructors/progress/payment/date) is deterministic and clearly marked as preview-safe values from adapters.
- Supported parity breakpoints for sign-off are mobile and desktop; if tablet-specific QA is requested, it is additive and does not block initial implementation.
- No feature flag is required for rollout; standard deploy gates and test coverage are the release control.

## Requirements Traceability
- Source of truth: `docs/epics/product_overhaul/image_preview/requirements.yml`
- Plan verification command:
  - `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py docs/epics/product_overhaul/image_preview --action verify_plan`
- Stage gate command:
  - `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py docs/epics/product_overhaul/image_preview --action master_validate --stage plan_present`

## Phase 1: Contract Baseline and Safety Net
- Goal: Lock parity-critical rendering contracts and establish a regression harness before extraction/wiring.
- Tasks:
  - [ ] Trace and document required assigns for:
    - `OliWeb.Workspaces.Student.course_card/1`
    - `OliWeb.Common.CardListing.render/1`
    - `OliWeb.Delivery.StudentOnboarding.Intro.render/1`
  - [ ] Add/extend baseline tests covering current runtime rendering and fallback behavior for each target context (pre-change parity snapshots/assertions).
  - [ ] Identify runtime dependencies that are not preview-safe (DB lookups, click handlers, route assumptions) and codify them as seam requirements.
  - [ ] Define telemetry event contract and metadata whitelist for preview events (no PII).
  - [ ] Capture manual parity checklist matrix (context x breakpoint x fallback state) for later phase gates.
- Testing Tasks:
  - [ ] Extend runtime regression tests for student workspace, course picker, and onboarding intro rendering.
  - [ ] Command(s): `mix test test/oli_web/live/workspaces/student_test.exs test/oli_web/live/new_course/select_source_test.exs test/oli_web/live/delivery/onboarding_wizard/student_onboarding_wizard_test.exs`
  - [ ] Pass criteria: tests are green and assert canonical fallback/image behavior currently in production.
- Definition of Done:
  - Runtime component contracts are explicit and referenced by tests.
  - Risky runtime-only dependencies are enumerated with mitigation seams.
  - Baseline tests pass without preview implementation enabled.
- Gate:
  - Gate A: parity safety net is green and contract inventory is complete; preview implementation work can start.
- Dependencies:
  - None.
- Parallelizable Work:
  - Runtime test expansion for each of the three contexts can run in parallel because they target separate files and shared expectations only.

## Phase 2: Preview Infrastructure and Authorization Wiring
- Goal: Introduce shared preview infrastructure in Product details LiveView with context switching, authz-preserving rendering boundaries, and telemetry scaffolding.
- Tasks:
  - [ ] Add `preview_context` assign and `"select_preview_context"` event handling to `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive`.
  - [ ] Create `OliWeb.Products.ImagePreview.RuntimePreview` to dispatch by context and call canonical runtime components.
  - [ ] Create `OliWeb.Products.ImagePreview.Adapters` with context-specific assign builders:
    - `my_course_assigns/2`
    - `course_picker_assigns/2`
    - `welcome_assigns/2`
  - [ ] Add invalid-context fallback to `:my_course` and structured warning logs.
  - [ ] Wire telemetry for context selection and render result/duration with AppSignal tags.
  - [ ] Ensure preview controls remain gated by existing template-management authorization and are absent for unauthorized users.
- Testing Tasks:
  - [ ] Add/extend LiveView tests in `test/oli_web/live/workspaces/course_author/products/details_live_test.exs` for selector rendering, context switching, and unauthorized visibility/access behavior.
  - [ ] Add telemetry unit tests asserting emitted events/metadata for context selection and render results.
  - [ ] Command(s): `mix test test/oli_web/live/workspaces/course_author/products/details_live_test.exs`
  - [ ] Pass criteria: selector/authz/telemetry tests pass and no new unauthorized code path is introduced.
- Definition of Done:
  - Product details LiveView can switch preview contexts safely.
  - RuntimePreview and adapter modules compile and are exercised by tests.
  - Authz behavior matches existing server-side template access policy.
- Gate:
  - Gate B: preview infrastructure is stable and authorization/telemetry checks are green.
- Dependencies:
  - Phase 1 Gate A.
- Parallelizable Work:
  - Adapter module implementation and telemetry wiring can run in parallel after interface signatures are agreed.

## Phase 3: Runtime Component Preview-Safe Seams
- Goal: Add minimal, backward-compatible seams to runtime components so preview can reuse them without runtime side effects.
- Tasks:
  - [ ] `OliWeb.Workspaces.Student.course_card/1`: add optional preview attrs for instructor/progress/date display inputs and non-interactive mode to avoid runtime-only queries/events in preview.
  - [ ] `OliWeb.Common.CardListing.render/1`: add optional non-interactive preview mode and no-op selection handling for preview rendering.
  - [ ] `OliWeb.Delivery.StudentOnboarding.Intro.render/1`: confirm adapter-provided assigns satisfy intro rendering without introducing new seam unless required.
  - [ ] Keep defaults fully backward compatible for existing runtime call sites.
  - [ ] Ensure canonical image fallback remains sourced via `OliWeb.Common.SourceImage.cover_image/1`.
- Testing Tasks:
  - [ ] Add seam-focused regression tests validating runtime default behavior is unchanged when preview opts are absent.
  - [ ] Add tests validating preview mode suppresses interactive/runtime-only dependencies.
  - [ ] Command(s): `mix test test/oli_web/live/workspaces/student_test.exs test/oli_web/live/new_course/select_source_test.exs test/oli_web/live/delivery/onboarding_wizard/student_onboarding_wizard_test.exs`
  - [ ] Pass criteria: runtime behavior remains unchanged and preview-safe options work deterministically.
- Definition of Done:
  - Required seams are implemented narrowly with safe defaults.
  - Runtime regressions are blocked by tests.
  - No additional DB query behavior is introduced by preview-mode rendering paths.
- Gate:
  - Gate C: runtime component seams are verified safe and backward compatible.
- Dependencies:
  - Phase 2 Gate B.
- Parallelizable Work:
  - My Course and Course Picker seam changes can proceed in parallel; Welcome verification can run concurrently because it is adapter-shape focused.

## Phase 4: Context Integration, Parity, and Failure Handling
- Goal: Complete end-to-end rendering for all three preview contexts with fallback parity and responsive behavior checks.
- Tasks:
  - [ ] Wire each context in `RuntimePreview` to real runtime component entry points using adapter outputs.
  - [ ] Implement deterministic fallback behavior for missing/invalid image data and invalid adapter outputs (safe fallback preview block + telemetry/logging).
  - [ ] Ensure preview contexts remain non-interactive while preserving visual parity with runtime surfaces.
  - [ ] Validate responsive behavior at mobile and desktop breakpoints for each context.
  - [ ] Externalize any new preview labels/help text for localization.
- Testing Tasks:
  - [ ] Add integration tests proving each selector option renders its intended runtime component path (FR-001/FR-002/FR-003 coverage).
  - [ ] Add fallback tests for missing/invalid images across all contexts.
  - [ ] Add breakpoint-aware UI assertions where practical and capture manual parity checklist evidence.
  - [ ] Command(s): `mix test test/oli_web/live/workspaces/course_author/products/details_live_test.exs test/oli_web/live/workspaces/student_test.exs test/oli_web/live/new_course/select_source_test.exs test/oli_web/live/delivery/onboarding_wizard/student_onboarding_wizard_test.exs`
  - [ ] Pass criteria: all context/fallback/parity tests pass and manual parity checklist has no blocking deviations.
- Definition of Done:
  - My Course, Course Picker, and Welcome previews render through canonical runtime units.
  - Fallback behavior matches runtime behavior and does not crash LiveView.
  - Responsive and localization requirements are satisfied for release scope.
- Gate:
  - Gate D: functional parity and fallback behavior accepted across all contexts.
- Dependencies:
  - Phase 3 Gate C.
- Parallelizable Work:
  - Context-specific integration tests can run in parallel after RuntimePreview dispatch wiring is complete.

## Phase 5: Final Verification, Operational Readiness, and Spec Sync
- Goal: Close non-functional gates, verify full-suite stability, and prepare release with updated documentation and QA artifacts.
- Tasks:
  - [ ] Execute targeted performance checks for initial render/context switch against PRD budgets; investigate and resolve regressions.
  - [ ] Validate telemetry coverage in staging-like environment (selection/render/failure events, AppSignal tags, no PII).
  - [ ] Confirm tenancy/authz behavior with negative-path checks (unauthorized users cannot access controls; no cross-template leakage).
  - [ ] Run full impacted test suites and resolve failures.
  - [ ] Update feature documentation/QA runbook notes with parity checklist outcomes and known limitations/assumptions.
- Testing Tasks:
  - [ ] Run focused suites plus broader regression for touched areas.
  - [ ] Command(s): `mix test test/oli_web/live/workspaces/course_author/products/details_live_test.exs test/oli_web/live/workspaces/student_test.exs test/oli_web/live/new_course/select_source_test.exs test/oli_web/live/delivery/onboarding_wizard/student_onboarding_wizard_test.exs`
  - [ ] Command(s): `mix test`
  - [ ] Pass criteria: targeted suites and full suite green; non-functional checks documented and accepted.
- Definition of Done:
  - Performance, authz/tenancy, observability, and accessibility checks are complete.
  - Full test pass confirms no regressions in destination runtime surfaces.
  - Release notes/checklist for image preview are documented and implementation is ready for deploy.
- Gate:
  - Gate E: release readiness approved with all mandatory quality gates passed.
- Dependencies:
  - Phase 4 Gate D.
- Parallelizable Work:
  - Performance profiling and telemetry validation can run in parallel with documentation updates once functional tests are green.

## Parallelisation Notes
- Phase 1 test-hardening work can be split by context (My Course, Course Picker, Welcome) in parallel.
- Phase 2 adapter construction and telemetry plumbing can run in parallel after context enum/event contract is set.
- Phase 3 seam implementation for My Course and Course Picker can run concurrently; Welcome usually requires verification-only work.
- Within Phase 4, context-specific parity/fallback test authoring can run in parallel after shared dispatch wiring lands.
- Phase 5 operational checks (performance, telemetry, docs) can run in parallel after the Phase 4 gate, but final sign-off requires all tracks complete.

## Phase Gate Summary
- Gate A (post Phase 1): Runtime contract inventory and baseline parity tests are complete and green.
- Gate B (post Phase 2): Preview infrastructure, selector flow, authz gating, and telemetry scaffolding are green.
- Gate C (post Phase 3): Runtime components expose preview-safe seams with backward-compatible behavior.
- Gate D (post Phase 4): All three contexts pass parity/fallback/responsive verification.
- Gate E (post Phase 5): Non-functional, full regression, and release-readiness checks are all approved.
