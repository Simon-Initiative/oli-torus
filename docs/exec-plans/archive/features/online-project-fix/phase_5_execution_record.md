# Phase 5 Execution Record

Work item: `docs/exec-plans/current/features/online-project-fix`
Phase: `5 - System-Admin Route and Thin LiveView`

## Scope from plan.md
- Expose the validated project repair context through `/workspaces/course_author/:project_id/repair_tool`.
- Gate the route to system administrators while retaining standard authoring workspace project assignment and authorization hooks.
- Render context report/result structs in an accessible, thin LiveView without duplicating detection or mutation rules in `OliWeb`.
- Add one focused route/pipeline smoke test for system-admin access and non-system-admin denial.

## Implementation Blocks
- [x] Core behavior changes
  - Added `OliWeb.Workspaces.CourseAuthor.ProjectRepairLive`.
  - LiveView mount starts async `Oli.Authoring.ProjectRepair.analyze_project/3` from server-side project/author assigns.
  - `"make_changes"` event sends no page/activity ids or repair plan, requires server-side confirmation state, and starts async `repair_project/3` from current server-side state.
  - The displayed report is replaced with `report_after_repair` for completed, partial, and structured failed repair results.
  - Display analysis uses bounded preview limits while preserving full summary counts; repair analysis remains uncapped.
- [x] Data or interface changes
  - No schema changes.
  - Added internal preview-limit options to the context analysis path.
  - Added `page_count` to `SharedActivityReference` so bounded UI page lists still show full group cardinality.
  - Added only a Phoenix LiveView route and server-rendered presentation.
- [x] Access-control or safety checks
  - Added a dedicated `:system_admin_authoring_workspaces` LiveSession under `:browser`, `:authoring_protected`, and `:require_authenticated_system_admin`.
  - Retained `SetProjectOrSection` and `AuthorizeProject` on-mount hooks.
  - LiveView relies on the context's existing system-admin reauthorization for defense in depth.
- [x] Observability or operational updates when needed
  - No new operational instrumentation in Phase 5; Phase 4 context instrumentation remains the source of operational events.

## Test Blocks
- [x] Tests added or updated
  - Added `test/oli_web/project_repair_route_test.exs`.
  - Covered successful mount for a system administrator.
  - Covered non-system-admin redirect before LiveView mount.
  - Covered server-enforced repair confirmation and successful async repair result.
  - Covered bounded shared-group display retaining the full page count.
- [x] Required verification commands run
  - `mix test test/oli_web/project_repair_route_test.exs test/oli/authoring/project_repair_test.exs`
  - `mix format --check-formatted lib/oli_web/router.ex lib/oli_web/live/workspaces/course_author/project_repair_live.ex test/oli_web/project_repair_route_test.exs`
  - `mix compile --warnings-as-errors`
  - `python3 /Users/darren/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/features/online-project-fix --check all`
- [x] Results captured
  - Targeted route/context tests: passed, `34 tests, 0 failures`.
  - Format check: passed.
  - Compile with warnings as errors: passed.
  - Preflight validation: passed.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - No implementation divergence from Phase 5 plan.
- [x] Open questions added to docs when needed
  - No new open questions from Phase 5.

## Review Loop
- Round 1 findings:
  - Performance: synchronous mount/repair work and unbounded LiveView diff.
  - UI: destructive repair lacked confirmation; summary metric semantics were fragile.
  - Requirements: missing repairable affected-page summary card.
  - Security/Elixir: confirmation needed server-side enforcement.
- Round 1 fixes:
  - Moved analysis and repair to `start_async`/`handle_async`.
  - Added inline confirmation with server-side `confirming_repair?` guard.
  - Replaced summary `<dl>` with list/card semantics.
  - Added repairable affected-page summary card.
  - Added route tests for confirmation, direct-event bypass, and repair result.
- Round 2 findings (optional):
  - UI/requirements: bounded shared-group display showed truncated page count.
  - Elixir: lock acquisition could infer ownership ambiguously for same-admin concurrent repairs.
  - Performance: UI analysis still built complete issue lists; repair clone loop resolved source revisions per clone.
- Round 2 fixes (optional):
  - Added `SharedActivityReference.page_count` and rendered full page count with truncation notice.
  - Reworked repair lock acquisition to a row-locking all-or-none transaction.
  - Added preview limits to analysis and used them from the LiveView only.
  - Added pre-resolved `ContainerEditor.deep_copy_activity_revision/4` and batched source revision lookup per repaired page.

## Manual Verification Notes
- Automated route/pipeline coverage verifies system-admin access and non-system-admin denial.
- Automated LiveView route coverage verifies confirmation, success status, and bounded display count.
- Full browser/manual checks for prepared projects remain part of Phase 6 integrated verification.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
