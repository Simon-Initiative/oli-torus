# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/core`
Phase: `2`

## Scope from plan.md
- Implement the authoritative context boundary for customization writes.
- Centralize authorization, target validation, candidate review, and count protection.

## Implementation Blocks
- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

Notes:
- Added authorized, idempotent enable/disable APIs and semantic exclude/restore wrappers for embedded activities, whole bank selections, and selection-local candidates.
- Added target resolution against the section's current published page revision, rejecting missing sections/pages/targets and adaptive pages.
- Selected `Sections.is_instructor?/2`, `Sections.is_admin?/2`, and `Accounts.at_least_content_admin?/1` as the canonical write authorization helpers.
- Added selection-level reads and candidate review state with enabled and disable-allowed annotations.
- Candidate disables lock the page's `SectionResource` row, then re-resolve candidates and enforce the selection count inside the same transaction.
- Candidate review uses a standard paged result query plus a bounded active-count query so stale exclusions are ignored without loading the full bank for display.
- Candidate target validation uses one bounded query restricted to the candidate resource, while count enforcement uses a bounded blacklist/count query without materializing the full matching bank.
- Dedicated write telemetry was deferred because no equivalent Delivery context convention exists; explicit error tuples remain the operational contract.

## Test Blocks
- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Verification:
- `mix test test/oli/delivery/instructor_customizations`
- `mix test test/oli/activities/realizer/query_execution_test.exs test/oli/activities/realizer/selection_test.exs test/oli/delivery/instructor_customizations`
- `mix format --check-formatted lib/oli/delivery/instructor_customizations.ex lib/oli/delivery/instructor_customizations/target_resolver.ex test/oli/delivery/instructor_customizations/write_api_test.exs`
- `mix compile --warnings-as-errors`
- `python3 /Users/gastonabella/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/instructor_customizations/core --check all`

Results:
- Targeted Phase 2 tests passed: `22 tests, 0 failures`.
- Realizer compatibility and Phase 2 tests passed together: `42 tests, 0 failures`.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

Notes:
- Updated the FDD and informal design to require an authorized actor for every write, including future scenario callers; the proposed `authorize?: false` bypass was rejected.
- Marked all Phase 2 plan tasks complete and recorded the telemetry decision.
- No PRD changes were required.

## Review Loop
- Round 1 findings:
  - The proposed `authorize?: false` option weakened the centralized authorization boundary.
  - Candidate review loaded every matching bank activity before applying requested pagination.
  - Candidate disable validation also materialized every matching bank activity.
  - Candidate paging values needed strict integer validation before reaching the existing SQL builder.
  - User authorization depended on callers preloading platform roles.
- Round 1 fixes:
  - Removed the authorization bypass and synchronized the FDD/informal design.
  - Changed candidate review to query only the requested page and derive active count with a bounded query.
  - Reworked candidate validity and count enforcement around bounded candidate and blacklist/count queries.
  - Added paging validation and targeted coverage.
  - Preloaded platform roles inside the context before applying user admin checks.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
