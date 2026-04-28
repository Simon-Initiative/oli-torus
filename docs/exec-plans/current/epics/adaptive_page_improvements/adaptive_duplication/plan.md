# Adaptive Duplication - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/adaptive_page_improvements/adaptive_duplication/prd.md`
- FDD: `docs/exec-plans/current/epics/adaptive_page_improvements/adaptive_duplication/fdd.md`

## Scope
Implement adaptive page duplication as a feature-flagged authoring workflow that duplicates an adaptive page, bulk-copies its referenced adaptive screens, remaps duplicated resource references, and preserves existing non-adaptive duplication behavior.

Guardrails:
- keep the existing non-adaptive duplication path intact (`FR-006`, `AC-010`)
- preserve `custom.sequenceId` and `custom.sequenceName` on the duplicated page (`FR-004`, `AC-005`)
- use set-based persistence inside one transaction rather than per-screen inserts (`FR-003`, `AC-004`)
- fail closed on unresolved or malformed adaptive references (`FR-005`, `AC-008`, `AC-009`)
- do not add feature-specific telemetry or observability work for this item
- do not introduce schema changes, migrations, or cross-project duplication behavior

## Clarifications & Default Assumptions
- The adaptive path will be introduced behind the canary rollout feature `adaptive_duplication`; when the rollout stage is `off`, current UI and backend behavior remain unchanged (`FR-001`, `AC-001`, `AC-002`).
- The new module boundary is `Oli.Authoring.Editing.AdaptiveDuplication`, with `ContainerEditor.duplicate_page/4` remaining the caller and non-adaptive fallback.
- "Single query" is implemented as a small number of set-based bulk insert/update queries inside one `Repo.transaction`, not as a single hand-written SQL statement across all touched tables.
- The first implementation will target the rewrite surfaces named in the FDD: page `activity-reference.activity_id`, screen `destinationScreenId`, `activitiesRequiredForEvaluation`, and nested `idref` / `resource_id` references (`FR-003`, `FR-004`, `AC-004`, `AC-006`).
- Scenario coverage is not planned initially; targeted ExUnit and LiveView tests are the expected confidence level unless implementation reveals workflow risk that cannot be covered there.

## Phase 1: Feature Gate And Call Path
- Goal: Create the adaptive-specific entry path without changing non-adaptive duplication behavior.
- Tasks:
  - [ ] Add a scoped feature-flag check for adaptive duplication at the curriculum action affordance and at the server-side duplication branch (`FR-001`, `FR-006`, `AC-001`, `AC-002`, `AC-010`).
  - [ ] Update `ContainerEditor.duplicate_page/4` to detect adaptive pages and delegate to `Oli.Authoring.Editing.AdaptiveDuplication`, while preserving the current path for non-adaptive pages (`FR-006`, `AC-010`).
  - [ ] Scaffold the adaptive duplication module interface and structured error contract expected by the caller (`FR-005`, `AC-008`, `AC-009`).
- Testing Tasks:
  - [ ] Add or update LiveView coverage for duplicate action visibility with the feature flag on and off (`AC-001`, `AC-002`).
  - [ ] Add a regression test proving non-adaptive duplication still uses existing behavior (`AC-010`).
  - [ ] Command(s): `mix test test/oli_web/live/curriculum/container_test.exs test/oli/editing/container_editor_test.exs`
- Definition of Done:
  - Adaptive pages are routed to a dedicated backend branch only when the feature flag is enabled.
  - Non-adaptive duplication behavior and tests remain unchanged.
- Gate:
  - The adaptive path is reachable only behind the flag and does not regress non-adaptive duplication.
- Dependencies:
  - None.
- Parallelizable Work:
  - LiveView affordance updates and backend branch scaffolding can proceed in parallel once the feature-flag contract is agreed.

## Phase 2: Bulk Screen Duplication Engine
- Goal: Implement the transactional, set-based duplication of adaptive screen resources and revisions and produce the old-to-new resource mapping (`FR-002`, `FR-003`, `AC-003`, `AC-004`).
- Tasks:
  - [ ] Implement source-page validation and ordered extraction of adaptive screen refs from the deck page content (`FR-002`, `AC-003`, `AC-005`).
  - [ ] Implement the bulk duplication phase for adaptive screens: set-based inserts into `resources`, `project_resources`, `revisions`, and current working-publication `published_resources`, all inside one transaction (`FR-003`, `AC-003`, `AC-004`).
  - [ ] Return deterministic mapping structures for source screen resource ids to duplicated screen resource ids and duplicated revision ids (`FR-002`, `FR-003`, `AC-003`, `AC-004`).
  - [ ] Add row-count and ownership assertions that force rollback on any mismatch (`FR-005`, `AC-008`).
- Testing Tasks:
  - [ ] Add backend tests for successful duplication of an adaptive page with multiple screens, verifying new screen resources and unchanged originals (`AC-003`, `AC-007`).
  - [ ] Add rollback tests for missing source revisions or insert-count mismatches (`AC-008`).
  - [ ] Command(s): `mix test test/oli/authoring/editing/adaptive_duplication_test.exs`
- Definition of Done:
  - The module can duplicate all referenced adaptive screens in one transaction and produce a complete old-to-new screen map.
  - Any persistence mismatch causes rollback with no partial duplicate left behind.
- Gate:
  - Bulk duplication is set-based and transactionally safe before any remapping logic is layered on.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Test fixture creation for adaptive source pages can proceed alongside the bulk insert implementation.

## Phase 3: Screen Remapping And Page Finalization
- Goal: Rewrite duplicated adaptive screen/page content to point exclusively at duplicated resources, then finalize the duplicated page (`FR-002`, `FR-004`, `FR-005`, `AC-004`, `AC-005`, `AC-006`, `AC-009`).
- Tasks:
  - [ ] Implement screen-content remapping for `authoring.flowchart.paths[*].destinationScreenId`, `authoring.activitiesRequiredForEvaluation[*]`, and nested `idref` / `resource_id` surfaces using the screen resource map (`FR-004`, `AC-006`).
  - [ ] Reuse or extract existing interop rewiring helpers where practical rather than duplicating traversal logic (`FR-004`, `AC-006`).
  - [ ] Bulk update only the duplicated screen revisions whose content changed (`FR-003`, `FR-004`, `AC-004`, `AC-006`).
  - [ ] Duplicate the adaptive page resource/revision and rewrite page `activity-reference.activity_id` plus any nested duplicated-screen resource refs, preserving deck order, `sequenceId`, and `sequenceName` (`FR-002`, `FR-004`, `AC-004`, `AC-005`).
  - [ ] Reattach the duplicated page through the existing container flow and propagate a user-facing failure when the adaptive duplication transaction aborts (`FR-005`, `AC-009`).
- Testing Tasks:
  - [ ] Add targeted remapper tests for each known rewrite surface in screen and page content (`AC-004`, `AC-006`).
  - [ ] Add an end-to-end authoring-side duplication test proving the duplicated page references only duplicated screens and preserves sequence metadata (`AC-004`, `AC-005`, `AC-006`).
  - [ ] Add failure-path tests ensuring no duplicated page entry or screens survive a remap failure (`AC-008`, `AC-009`).
  - [ ] Command(s): `mix test test/oli/authoring/editing/adaptive_duplication_test.exs test/oli/editing/container_editor_test.exs test/oli/interop/rewire_links_test.exs`
- Definition of Done:
  - All known duplicated-screen resource-id surfaces are rewritten correctly.
  - The duplicated page sequence listing points only at duplicated screens and preserves authored sequencing metadata.
- Gate:
  - Adaptive duplicates are internally consistent and fail closed on unsupported or malformed content.
- Dependencies:
  - Phase 2.
- Parallelizable Work:
  - Page-content remapping tests and screen-content remapping tests can be built in parallel once the mapping contract is stable.

## Phase 4: Verification And Release Readiness
- Goal: Close the feature with targeted regression coverage, manual verification notes, and work-item validation (`FR-001` through `FR-006`, `AC-001` through `AC-010`).
- Tasks:
  - [ ] Run targeted backend and LiveView suites covering flag gating, duplication success, remapping correctness, rollback behavior, and non-adaptive regression.
  - [ ] Perform manual authoring verification: duplicate an adaptive page, confirm copied-title behavior, confirm copied screens diverge from originals, and confirm forced failure leaves no duplicate behind (`AC-002`, `AC-003`, `AC-007`, `AC-009`).
  - [ ] Reconcile any implementation drift back into the work-item docs only if behavior changed from the approved PRD/FDD.
- Testing Tasks:
  - [ ] Run the targeted Elixir tests for this feature and any touched regression modules.
  - [ ] Run formatting on touched backend files.
  - [ ] Re-run harness validation if docs changed.
  - [ ] Command(s): `mix test test/oli/authoring/editing/adaptive_duplication_test.exs test/oli/editing/container_editor_test.exs test/oli_web/live/curriculum/container_test.exs && mix format`
- Definition of Done:
  - All targeted automated tests pass.
  - Manual authoring checks confirm the duplicate behaves as specified.
  - The work item remains validated and traceable.
- Gate:
- The feature is ready for guarded rollout behind `adaptive_duplication` using the incremental rollout admin UI.
- Dependencies:
  - Phases 1 through 3.
- Parallelizable Work:
  - Manual verification can begin once the automated duplication path is stable, while final regression and formatting are run in parallel.

## Parallelization Notes
- The safest split is by seam, not by file count: UI flag affordance work, backend branch wiring, and backend test fixture setup can overlap early.
- Bulk-copy persistence and remapper implementation should stay serialized once transaction semantics are in flight, because they share the same mapping contract.
- No telemetry, metrics, or dashboard tasks should be added during implementation even though `harness.yml` enables telemetry by default; the PRD/FDD explicitly remove that requirement for this work item.

## Phase Gate Summary
- Gate A: Adaptive duplication is feature-flagged and non-adaptive duplication is unchanged.
- Gate B: Bulk screen duplication is set-based, mapped, and transactionally safe.
- Gate C: Remapped duplicated screens and duplicated page point only at duplicated resources while preserving sequence metadata.
- Gate D: Targeted automated and manual verification pass, and the feature is ready for guarded rollout.
