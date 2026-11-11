# Phase 1 Execution Record

Work item: `docs/exec-plans/current/features/genai-redesign`
Phase: 1 — Verify transport capacity and settle the execution contract
Status: completed for Hackney/OpenAI; Claude work explicitly deferred by the FDD.

## Scope from plan.md

- Verify installed transport behavior with repeatable tests and settle the execution contract.
- The earlier execution record incorrectly treated production tier-pool reconciliation and routing as Phase 1 blockers. They are Phase 2 and Phase 3 tasks in the approved plan; their implementation and integration tests remain there.
- Preserve the approved immediate-replacement policy and the explicit instruction to leave Claude implementation unchanged.

## Implementation Blocks

- [x] Inspect installed Hackney, OpenAI and Claude call paths; document version-specific findings in `docs/exec-plans/current/features/genai-redesign/design/transport-evidence.md`.
- [x] Settle replacement policy: create and select a new pool immediately, accept temporary combined occupancy above its capacity, and keep retiring generations visible while old work drains. Do not use in-place shrink.
- [x] Define logical identity, physical generations, one-origin constraint, timeout classification, probe/admin separation and the request-start retirement fence required by the Phase 2/3 integration.
- [x] Select initial defaults: checkout timeout 1,000 ms; administrative transport capacity four per node. These are integration defaults, not new legacy-router settings.
- [x] Fix actual OpenAI early-stream cleanup: stop asynchronous delivery and explicitly close the Hackney request. `stop_async/1` alone leaves a checkout held while the caller stays alive.
- [x] Record Claude's source-level limitations and defer its transport implementation and runtime verification, as directed by the FDD.

## Test Blocks

- [x] Added 11 real-transport tests in `test/oli/gen_ai/transport_pool_semantics_test.exs`: fixed-capacity queueing and timeout removal; queued and active caller death; HTTPoison async owner death; in-place shrink behavior; replacement overlap, new-pool capacity and old-pool retirement; idle socket reuse; multiple-origin bound bypass; actual OpenAI SSE completion, caller kill, living consumer cancellation; and explicit async stop versus close.
- [x] Regression-first verification: the living-caller cancellation test failed before the adapter cleanup fix and passed afterward. The test deliberately keeps the caller alive after cancellation to avoid hiding the leak behind process-death cleanup.
- [x] `mix test test/oli/gen_ai/transport_pool_semantics_test.exs`: 11 tests, zero failures.
- [x] `mix test test/oli/gen_ai/`: 244 tests, zero failures, 3 excluded. ExUnit progress and summary were clean; existing startup/migration/seed output precedes ExUnit.
- [x] `mix format --check-formatted lib/oli/gen_ai/completions/open_ai_compliant_provider.ex test/oli/gen_ai/transport_pool_semantics_test.exs`: passed.
- [x] `git diff --check`: passed.

## Work-Item Sync

- [x] Informal design, requirements, FDD and plan reflect accepted temporary capacity overlap.
- [x] Phase 1 checklist is complete for the verified Hackney/OpenAI path, with Claude explicitly deferred.
- [x] FDD, plan and evidence specify the one-origin restriction and distinguish verified transport primitives from later manager/routing integration.
- [x] Requirements remain proposed for later implementation; this phase does not claim complete-feature acceptance.

## Review Loop

- Prior review identified that raw synchronous tests did not prove the OpenAI adapter path and that the initial async test had a synchronization race. Full adapter tests and async-header synchronization now address those gaps.
- Current harness-review round: security and performance reviews found no actionable issues. Elixir review found no actionable issues. Requirements review found inconsistent Claude scope across the PRD, requirements and plan; those documents now explicitly defer Claude implementation and runtime verification.

## Done Definition

- [x] Phase 1 transport evidence, decisions and tests complete within the approved plan and Claude deferral.
- [x] Focused tests and required formatting pass.
- [x] Current review round complete and findings resolved.
- [x] Preflight and postflight work-item validation pass.
