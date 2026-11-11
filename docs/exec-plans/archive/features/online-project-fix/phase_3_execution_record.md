# Phase 3 Execution Record

Work item: `docs/exec-plans/current/features/online-project-fix`
Phase: `3 - Lock-Aware Deterministic Repair`

## Scope from plan.md
- Derive repair work only from fresh server-side analysis and revision-bearing fingerprints.
- Lock every source activity and participant page in deterministic order and guarantee best-effort cleanup.
- Preserve one lowest-id keeper page per shared activity and repair every non-keeper page transactionally.
- Reuse established activity-copy and authoring revision APIs; preserve missing references and Adaptive pages.
- Return structured completed, partial, and failed results with a fresh after-report.
- Do not implement routing, LiveView behavior, or operational telemetry.

## Implementation Blocks
- [x] Core behavior changes
  - Added `Oli.Authoring.ProjectRepair.Repair` to build deterministic repair fingerprints from fresh analysis, select the lowest page resource id as keeper, invert non-keeper work per page, clone shared source activities through `ContainerEditor.deep_copy_activity/3`, rewire nested Basic-page references with `PageContent.map/2`, recompute `activity_refs`, and write page revisions through `ChangeTracker.track_revision/3`.
  - Missing activity references remain report-only and are never passed to clone or removal logic.
  - Adaptive pages remain excluded by the existing Basic-page predicate before planning or mutation.
- [x] Data or interface changes
  - `ProjectRepair.repair_project/3` now returns real `RepairResult` values for completed, failed, and partial repairs instead of the prior phase-boundary placeholder.
  - Added `AuthoringResolver.existing_activity_resource_ids/2` in the earlier analysis path and kept its activity-only projection compatible with Phase 3 repairability checks.
  - Hardened the page analysis stream join so a working-publication mapping is trusted only when the selected revision belongs to the same resource id.
- [x] Access-control or safety checks
  - Repair still reuses the Phase 1 system-admin authorization and persisted-actor reload before resolving project content.
  - Repair acquires all participant source-activity and page locks in deterministic order before mutation.
  - Repair uses repair-owned conditional lock acquisition with a `lock_updated_at` ownership stamp, so an existing same-admin lock is a conflict and release/refresh only affect locks this invocation still owns.
  - Repair reruns analysis after locks and aborts with `:stale_project_state` when the repair fingerprint changed.
  - Each changed page is one transaction, so page-local clone and page-revision failures roll back together while earlier committed pages remain retryable.
- [x] Observability or operational updates when needed
  - No Phase 3 telemetry/logging was added; operational instrumentation remains intentionally deferred to Phase 4.

## Test Blocks
- [x] Tests added or updated
  - Added/updated context tests for missing-only report-only repair, deterministic keeper behavior, clone fidelity, nested rewiring, missing-reference preservation, Adaptive-page exclusion, idempotent rerun, multiple groups affecting one page, fresh analysis instead of browser preview, post-lock stale fingerprint rejection, lock conflict cleanup, same-admin lock non-adoption, copy failure rollback/partial retry, page-update failure rollback/retry, and corrupt mapping/revision mismatch hardening.
- [x] Required verification commands run
  - `mix test test/oli/authoring/project_repair_test.exs`
  - `mix test test/oli/editing/container_editor_test.exs`
  - `mix test test/oli/publishing/authoring_resolver_test.exs`
  - `mix format --check-formatted lib/oli/publishing/authoring_resolver.ex lib/oli/authoring/project_repair.ex lib/oli/authoring/project_repair/analysis.ex lib/oli/authoring/project_repair/repair.ex lib/oli/authoring/project_repair/report.ex lib/oli/authoring/project_repair/repair_result.ex test/oli/authoring/project_repair_test.exs`
  - `mix compile --warnings-as-errors`
  - `python3 <skills_root>/validate/scripts/validate_work_item.py docs/exec-plans/current/features/online-project-fix --check all`
- [x] Results captured
  - `project_repair_test.exs`: 27 tests, 0 failures.
  - `container_editor_test.exs`: 12 tests, 0 failures.
  - `authoring_resolver_test.exs`: 22 tests, 0 failures.
  - Format check passed.
  - Compile with warnings as errors passed.
  - Work-item validation passed.
  - A plan-listed command using `test/oli/authoring/editing/container_editor_test.exs` was attempted and failed because that path does not exist in this checkout; the equivalent existing suite is `test/oli/editing/container_editor_test.exs` and passed.
  - An attempted parallel run of the two dependent suites produced startup/order noise, so the same suites were rerun sequentially and passed.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - No PRD/FDD/plan contract change was required for Phase 3. Implementation stayed within Gate C scope.
- [x] Open questions added to docs when needed
  - No new open questions were introduced for Phase 3.

## Review Loop
- Round 1 findings:
  - Security: pre-read plus `Locks.acquire/4` could adopt and later release another same-admin session's lock in a race.
  - Performance: lock acquisition performed duplicate reads per target; refresh attempted every lock before every page transaction.
  - Elixir/Ecto correctness: the page stream joined mapping to revision by revision id only, not resource id.
  - Requirements: AC-016 stale fingerprint rejection and AC-023 page-update failure lacked direct tests; this execution record still had no Gate C evidence.
- Round 1 fixes:
  - Replaced normal repair acquisition with conditional update-based, repair-owned locks and stamp-matched refresh/release.
  - Reduced refresh scope to the current page and that page's source activity locks.
  - Added the mapping/revision resource-id join predicate and regression coverage.
  - Added stale-fingerprint and page-update failure tests.
  - Completed this execution record.
- Round 2 findings (optional):
  - Not run; Round 1 findings were concrete and addressed, and verification passed after fixes.
- Round 2 fixes (optional):
  - N/A.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
