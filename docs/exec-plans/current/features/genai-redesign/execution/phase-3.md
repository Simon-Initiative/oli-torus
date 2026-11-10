# Phase 3 Execution Record

Work item: `docs/exec-plans/current/features/genai-redesign`
Phase: 3 — Pool routing, execution, and stream lifecycle
Status: complete for the in-scope OpenAI path; Claude implementation remains deferred.

## Scope from plan.md

Connect independently monitored Provider eligibility and actual isolated tier pools
to OpenAI production requests, bounded checkout, one guarded backup and stream cleanup.
Preserve the user-approved immediate generation replacement and explicit Claude deferral.

## Implementation Blocks

- [x] Replace active admission/breaker routing with actual occupancy hints.
- [x] Cache reconciled execution inputs and pass exact transport context through both completion paths.
- [x] Bound checkout and total inference; retry backup once only before output for narrowly eligible failures.
- [x] Handle SSE completion/errors/truncation and reliably reclaim transport on cancellation or process death.
- [x] Add pool, request, backup and cleanup telemetry without changing health from request outcomes.
- [x] Preserve unsupported Claude dispatch without claiming managed isolation or changing its adapter.

## Test Blocks

- [x] Real transport coverage for occupancy routing, isolation, races, timeout, cancellation,
  kill, pre-output retry, no retry after content/tool fragments, inactivity and replacement.
- [x] Expanded GenAI, dialogue, administration and migration regression run: 349 tests,
  zero failures, three excluded after review fixes.
- A pre-existing asynchronous telemetry helper test captured unrelated concurrent dialogue
  events. Its local handler now accepts only its synchronous emitting process and detaches
  on failure; shared support/configuration is unchanged.
- Final gate command:
  `mix test test/oli/gen_ai/ test/oli/gen_ai_test.exs test/oli_web/live/gen_ai/ test/oli_web/components/delivery/dialogue_test.exs test/oli_web/live/dialogue/ test/oli/repo/migrations/genai_provider_migration_test.exs`.
  The final dialogue regression adds clean-up of partial assistant/tool state after
  a returned interruption; the Elixir follow-up review found no issues.
- `mix test`: **26 doctests, 9,961 tests, 14 failures, 75 excluded**. The failures
  include the previously recorded filesystem scan and shared-data/count assumptions
  in branding, institutions, inventories, resources, publisher/project controllers,
  plus a 100 ms assertion in the unchanged dialogue tool-error test. All eight
  failing files pass together in fresh isolation: **128 tests, zero failures**,
  including the Playwright scan and dialogue assertion. No unrelated production
  code or global test configuration was changed to hide full-suite failures.
- Diagnosed a repeatable database disconnect with the same-seed trace: the existing
  queued-continuation LiveView test could be forcefully torn down during persistence.
  Its module now uses ConnCase's existing `sandbox_owner` option and the continuation
  test explicitly stops the view normally before proxy teardown. No shared support
  or global test configuration changed. The final **349-test** gate with
  `--seed 902969` passes with clean ExUnit progress/summary and no disconnect output.
- `mix format --check-formatted` over every changed/new Elixir file: passed.
- `git diff --check` and harness work-item validation: passed.

## Work-Item Sync

- [x] Execution defaults, adapter boundaries and rollout distinction documented in
  `docs/exec-plans/current/features/genai-redesign/design/phase-3-execution.md`.
- [x] Plan/FDD synchronized; preflight and post-edit validation pass.

## Review Loop

- Security: bounded complete SSE events as well as unfinished buffers before decoding;
  real complete/split oversized-event regressions. Re-review found no remaining issue.
- Performance: route from protected per-config ETS snapshots independently of blocking
  reloads, with owner-death cleanup of the discovery handle; restored measured router
  duration. Re-review found no remaining issue.
- Elixir: retain legacy Claude credentials while checking current cached Provider
  administrative state; use independent deadline guardian during blocked callbacks;
  ignore null SSE content and validate token payloads. Real regression coverage added.
  Re-review found no remaining issue; final dialogue cleanup and local database-owner
  test isolation were also reviewed without findings.
- Requirements: distinguish native checkout timeout, cancellation and startup deadline;
  correctly label combined checkout/connect startup timing and explicitly document the
  installed API's pure-wait instrumentation limitation. Add absent/ineligible-backup
  coverage and strengthen the total deadline test across both attempts.
  Re-review found no remaining issue.

## Done Definition

- [x] Phase tasks complete and final targeted tests pass; full-suite limits recorded.
- [x] Required reviews resolved.
- [x] Work-item synchronization and validation pass.
