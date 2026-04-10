# Module-Level Log Controls - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/module-level-log-controls/prd.md`
- FDD: `docs/exec-plans/current/module-level-log-controls/fdd.md`

## Scope

Implement local-node module-level runtime log controls on the existing `/admin/features` page. The
delivery includes a backend runtime override service, a supervised local override registry,
additive UI changes in `FeaturesLive`, and automated coverage for authorization, validation, state
display, and clear behavior. The plan explicitly excludes cluster-wide coordination, durable
persistence, and arbitrary code execution.

Check off the task checkboxes as tasks are completed, and update the status of each phase gate as you progress through the implementation.

## Clarifications & Default Assumptions

- The repository-local harness contract files referenced by the planning skill are not present, so this plan follows the approved PRD, FDD, `AGENTS.md`, and the current Torus codebase structure.
- The first implementation should keep all behavior on the node handling the admin request, matching the current global log-level control.
- Existing `/admin/features` behavior, especially global log-level changes and scoped feature flag management, must remain intact.
- If an existing audit-log mechanism can be reused without significant coupling, include that integration in the implementation phase; otherwise, detailed Logger entries plus UI flash feedback are sufficient for first delivery.

## Phase 1: Runtime Override Service

- Goal: Implement the backend service and local registry for validated module-level overrides and shared override state.
- Tasks:
  - [x] Add a new runtime override service module, proposed as `Oli.RuntimeLogOverrides`, under `lib/oli/`.
  - [x] Implement level validation, module-name parsing, and safe existing-module resolution for module-level overrides. [AC-001] [AC-004]
  - [x] Implement `set_module_level/2`, `clear_module_level/1`, and `list_overrides/0` APIs. [AC-001] [AC-005] [AC-006]
  - [x] Add a supervised local registry process for active overrides and wire it into [application.ex](/Users/eliknebel/Developer/oli-torus/lib/oli/application.ex).
  - [x] Ensure global Logger level remains unchanged when a module override is applied. [AC-002]
  - [x] Add operational Logger entries for successful and failed module override actions.
- Testing Tasks:
  - [x] Add backend unit tests covering valid module override set, invalid module rejection, invalid level rejection, clear behavior, and no global-level mutation. [AC-001] [AC-002] [AC-004] [AC-006]
  - Command(s): `mix test test/...runtime_log_overrides*_test.exs`
- Definition of Done:
  - Backend service exists, starts under supervision, and supports module override set/list/clear flows.
  - Module-level requirements are covered by automated tests with passing results.
  - No regression is introduced to the current global log-level path.
- Gate:
  - Module-level backend tests pass and demonstrate `AC-001`, `AC-002`, `AC-004`, and `AC-006`.
- Dependencies:
  - None
- Parallelizable Work:
  - Audit-log reuse discovery can be investigated in parallel with the service implementation.
  - Initial `FeaturesLive` template sketching can begin once the service API shape is stable.

## Phase 2: Admin UI Integration

- Goal: Add module override controls to `FeaturesLive` without regressing current admin functionality.
- Tasks:
  - [ ] Extend [features_live.ex](/Users/eliknebel/Developer/oli-torus/lib/oli_web/live/features/features_live.ex) with a module-level override form section.
  - [ ] Add LiveView event handlers that delegate all runtime override mutations to `Oli.RuntimeLogOverrides`.
  - [ ] Render current local override state and clear actions. [AC-005]
  - [ ] Preserve the existing global log-level control and scoped feature flag sections.
  - [ ] Add or integrate audit-log recording if an existing mechanism can be reused without significant coupling.
  - [ ] Ensure server-side event handling preserves admin-only access assumptions. [AC-003]
- Testing Tasks:
  - [ ] Add LiveView tests for admin visibility, active-state rendering, flash confirmations, and clear actions. [AC-005]
  - [ ] Add authorization tests confirming non-admin users cannot use the new controls. [AC-003]
  - [ ] Add regression coverage for the existing global logging control on the same page.
  - Command(s): `mix test test/oli_web/live/...features*_test.exs`
- Definition of Done:
  - `/admin/features` exposes the new module-level controls with clear operator messaging.
  - Existing page behavior remains intact.
  - UI tests cover module workflows plus authorization and regression expectations.
- Gate:
  - LiveView tests pass for `AC-003` and `AC-005`, and manual review confirms the page remains coherent.
- Dependencies:
  - Phase 1
- Parallelizable Work:
  - Audit-log integration can remain optional until the page wiring is complete, as long as Logger-based observability is already in place.

## Phase 3: Hardening, Proof, and Documentation Sync

- Goal: Close operational gaps, verify the full slice end-to-end, and leave the work item ready for implementation or review handoff.
- Tasks:
  - [ ] Run the combined targeted test set for backend service and `FeaturesLive`.
  - [ ] Execute a manual validation pass on a dev node covering module override set/clear, invalid target handling, and UI messaging.
  - [ ] Confirm audit-log behavior: either reused existing audit logging with low coupling or documented the Logger-only fallback in implementation notes.
  - [ ] Update spec artifacts if implementation-driven adjustments are required.
  - [ ] Prepare proof references for completed ACs in code and tests.
- Testing Tasks:
  - [ ] Run the consolidated test commands and capture proof for all ACs.
  - [ ] Run formatter and any relevant compile checks before handoff.
  - Command(s): `mix test`; `mix format`; `mix compile`
- Definition of Done:
  - All targeted tests pass.
  - Manual validation confirms node-local module controls work as designed.
  - Observability and fallback audit behavior are explicit.
  - The implementation slice is ready for coding handoff or direct development.
- Gate:
  - Full targeted verification passes and the implementation is ready to enter development without unresolved scope ambiguity.
- Dependencies:
  - Phase 2
- Parallelizable Work:
  - Spec reconciliation and implementation-proof collection can proceed alongside manual validation after code is stable.

## Parallelization Notes

- Phase 1 backend service work can overlap with limited UI scaffolding, but UI event wiring should wait until the service interfaces stabilize.
- Phase 2 UI integration and any low-coupling audit-log reuse can proceed in parallel after backend APIs are available.
- Phase 3 is mostly serial because it depends on the integrated slice being complete, though proof collection and doc updates can run alongside manual validation.

## Phase Gate Summary

- Gate A: Module-level backend service and tests prove `AC-001`, `AC-002`, `AC-004`, and `AC-006`.
- Gate B: `/admin/features` integration and authorization tests prove `AC-003` and `AC-005`.
- Gate C: Consolidated verification, manual validation, and observability checks complete the slice for development handoff.
