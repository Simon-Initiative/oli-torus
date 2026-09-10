# Phase 1 Execution Record

Work item: `docs/exec-plans/current/features/preview-environment-tooling`
Phase: `1 - Establish the Preview Build and Runtime Safety Boundary`

## Scope from plan.md

- Establish a standalone, production-shaped `MIX_ENV=preview` release environment.
- Compile preview capabilities behind an immutable build marker and require strict runtime activation.
- Keep preview email local, propagate the selected build environment through Docker and preview workflows, and document the contract.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

Environment audit:

- `mix.exs` permanent startup and `lib/oli_web/endpoint.ex` static compression must treat `:preview` as production-like.
- `config/runtime.exs` must recognize `preview` and apply release-only database, endpoint, vault, queue, and SSL configuration.
- Runtime release shape must come from immutable `config_env()` and cannot be overridden by a runtime `MIX_ENV` value.
- Docker dependency selection, environment config copy, compilation, smoke execution, final-stage release copy, and runner environment must use the selected `MIX_ENV`.
- No dependency has a production-only `only:` selector requiring expansion. Test/dev-only dependencies remain excluded from preview.
- Gleam compiler and frontend aliases intentionally use Gleam's `build/dev` profile independently of `MIX_ENV`; the release smoke check verifies generated BEAM code is packaged from the release rather than loaded from the source build tree.

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Verification results:

- `mix test test/oli/dev_qa_tools/config_test.exs test/oli/dev_qa_tools/build_policy_test.exs` — 11 tests, 0 failures.
- `MIX_ENV=preview mix compile` — passed.
- `MIX_ENV=preview mix release --overwrite` — passed; created `_build/preview/rel/oli`.
- Preview release eval with runtime `MIX_ENV=test` and `DEV_QA_TOOLS_ENABLED=true` — passed; immutable preview marker, local mail adapter, and effective activation remained correct.
- `mix format` on changed Elixir/config files — passed.
- `mix format --check-formatted` and `git diff --check` — passed.
- Harness work-item validation (`--check all`) — passed before implementation and after review fixes.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged (no divergence found)
- [x] Open questions added to docs when needed (none)

## Review Loop

- Round 1 findings: Requirements review found one high-severity mutable-runtime-shape issue and two medium evidence gaps. Security, performance, Elixir, and UI reviews found no actionable issues.
- Round 1 fixes: Runtime shape now derives solely from immutable `config_env()`; tests now exercise local mail capture with activation disabled and enabled and cover standalone config, production workflow defaults, and the complete environment audit matrix. Security and requirements re-review found no remaining issues.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
