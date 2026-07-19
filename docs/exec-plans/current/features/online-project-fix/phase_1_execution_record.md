# Phase 1 Execution Record

Work item: `docs/exec-plans/current/features/online-project-fix`
Phase: `1 - Domain Contracts, Authorization, and Test Foundation`

## Scope from plan.md
- Establish the smallest compilable `Oli.Authoring.ProjectRepair` domain boundary.
- Add typed, content-free report and repair-result contracts.
- Implement system-admin authorization, project normalization, working-publication resolution, and safe option defaults.
- Establish real authoring fixtures for later Basic, Adaptive, nested, shared, and missing-reference tests.
- Do not implement streamed analysis, repair mutation, telemetry, routing, or LiveView behavior.

## Implementation Blocks
- [x] Core behavior changes
  - Added the fail-closed `Oli.Authoring.ProjectRepair` Phase 1 boundary.
  - Added current-project normalization for both `%Project{}` and slug inputs.
  - Added unpublished working-publication resolution and explicitly bounded internal batch options.
  - Valid project calls stop at explicit `:analysis_not_implemented` and `:repair_not_implemented` phase boundaries; no analysis or mutation behavior was introduced early.
- [x] Data or interface changes
  - Added documented/typespecified `Report`, `Summary`, `PageSummary`, `MissingActivityReference`, and `SharedActivityReference` contracts, with one top-level module per source file.
  - Added documented/typespecified `RepairResult` and `RepairFailure` contracts, with closed content-free failure and warning codes.
  - Added an explicit `repairable_shared_activity_affected_page_count` summary field so later phases cannot conflate repairable pages with shared missing references.
  - Domain contracts retain revision metadata needed by later stale checks but deliberately contain no page JSON or web URLs.
- [x] Access-control or safety checks
  - Both public entry points require a system-admin `%Author{}` and authorize before options, project, or publication lookup.
  - Authorization reloads the author by id and checks the current persisted role, preventing stale or hand-built caller structs from granting access.
  - Persisted projects are re-resolved and stale/hand-built structs must match both id and slug.
  - Inactive/unknown projects, missing working publications, malformed actors, unknown options, and out-of-range batch sizes return deterministic errors.
- [x] Observability or operational updates when needed
  - No telemetry or logging added; operational instrumentation belongs to Phase 4.

## Test Blocks
- [x] Tests added or updated
  - Added eleven focused context tests covering compact contracts, system-admin access through project/slug inputs, shared preparation for repair, unknown/stale projects, missing working publications, authorization precedence, current persisted role enforcement, nonexistent actors, option bounds, and real authoring fixtures.
  - Fixture foundation now creates and verifies current unpublished Basic, Adaptive, nested, shared, and intentionally missing activity-reference states for later phases.
- [x] Required verification commands run
  - `mix format lib/oli/authoring/project_repair.ex lib/oli/authoring/project_repair/*.ex test/oli/authoring/project_repair_test.exs`
  - `mix test test/oli/authoring/project_repair_test.exs`
  - `mix format --check-formatted lib/oli/authoring/project_repair.ex lib/oli/authoring/project_repair/*.ex test/oli/authoring/project_repair_test.exs`
  - `mix compile --warnings-as-errors`
- [x] Results captured
  - Targeted tests passed: 11 tests, 0 failures.
  - Targeted formatting check passed.
  - Full warnings-as-errors compilation passed after compiling 1,750 Elixir files.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - Updated the FDD contract to name the repairable-shared affected-page count explicitly and constrain repair failures/warnings to content-free reason codes.
  - No product or plan divergence found. Explicit not-implemented results are temporary fail-closed Phase 1 boundaries and will be replaced by the already-planned Phase 2 and Phase 3 engines.
- [x] Open questions added to docs when needed
  - No new open question introduced in Phase 1.

## Review Loop
- Round 1 findings:
  - Security/performance: processing options had lower bounds but no upper bounds.
  - Security: repair failures and warnings accepted arbitrary terms that could expose authored content or internal details.
  - Elixir/security: authorization trusted role data on the caller's `%Author{}` instead of current persisted state.
  - Elixir: multiple top-level contract modules shared source files.
  - Requirements: the repairable-shared affected-page count was ambiguously named, and repair lacked a direct valid non-admin test.
- Round 1 fixes:
  - Added explicit maximum cursor and resolver batch sizes with maximum and maximum-plus-one tests.
  - Replaced arbitrary failure/warning terms with closed content-free atom types and synchronized the FDD.
  - Reloaded actors by id before checking their system role; added demotion and nonexistent-account regression tests.
  - Split every contract into one top-level module per source file.
  - Added the explicit `repairable_shared_activity_affected_page_count` field and exercised repair with a persisted non-admin actor.
- Round 2 findings (optional): No additional findings during post-fix targeted verification.
- Round 2 fixes (optional): None required.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
