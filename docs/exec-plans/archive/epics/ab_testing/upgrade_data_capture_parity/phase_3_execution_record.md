# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity`
Phase: `3 - Preserve The Section-Wide Raw Outcome Stream`

## Scope from plan.md

- Add section enrollment identity to server-built evaluated-attempt xAPI context.
- Preserve the minimal raw activity contract across direct upload, Lambda, and replay/backfill.
- Add only nullable analytical storage needed for enrollment identity while retaining historical rows.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed (existing pipeline signals retained)

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Verification:

- `mix test test/oli/analytics/xapi test/oli/analytics/backfill test/oli/analytics/xapi_test.exs` - 76 tests, 0 failures, 1 excluded.
- `cloud/xapi-etl-processor/.venv/bin/python -m pytest cloud/xapi-etl-processor/tests` - 23 tests passed.
- `mix compile` - passed.
- `mix format` - passed.
- `git diff --check` - passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged (no design divergence; plan completion state updated)
- [x] Open questions added to docs when needed (none)

## Review Loop

- Round 1 findings: Elixir review found missing/multiple section-publication mappings could crash context construction and direct page/part enrollment propagation lacked coverage. Security and performance reviews found no concrete issues.
- Round 1 fixes: restored nullable publication behavior, made nil-project publication selection deterministic, kept enrollment resolution independent, and added missing-SPP plus page/part regression coverage.
- Round 2 findings: performance review found the independent enrollment lookup added a synchronous database round trip on the evaluated-attempt path.
- Round 2 fixes: consolidated enrollment and publication into independently nullable scalar subqueries returned by one parameterized section-anchored query. Final security, performance, and Elixir reviews reported no remaining concrete findings.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
