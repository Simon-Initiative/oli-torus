# Phase 2 Execution Record

Work item: `docs/exec-plans/current/features/preview-environment-tooling`
Phase: `2 - Build the Synchronous Scenario Release Interface`

## Scope from plan.md

- Add the Preview QA `bin/seed scenarios` release interface, compiled only in preview builds, and its immutable bundled registry.
- Keep compile-gated sources outside the recursively compiled `lib/` tree under `preview/lib/`.
- Execute bundled or custom YAML synchronously through the complete scenario DSL.
- Require YAML-defined active author and institution ownership without changing legacy scenario defaults.
- Provide bounded structured results, deterministic statuses, and no web, Oban, or persistent run surface.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Verification results:

- `mix test test/oli/release/preview_qa_tools_test.exs test/oli/scenarios/release_execution_test.exs test/oli/preview_qa_tools/build_policy_test.exs test/scenarios/use_directive test/scenarios/directives/hook_handler_test.exs` — 36 tests, 0 failures.
- `MIX_ENV=preview mix compile` and `MIX_ENV=preview mix release --overwrite` — passed; assembled the preview release with the executable `bin/seed` overlay.
- Enabled preview-release `bin/seed scenarios list` smoke test — passed and returned bundled metadata without parsing or executing YAML.
- `MIX_ENV=prod mix compile` — passed; `_build/prod/lib/oli/ebin/Elixir.Oli.Release.PreviewQATools.beam` is absent.
- `mix format`, `mix format --check-formatted`, and `git diff --check` — passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged (no divergence)
- [x] Open questions added to docs when needed (none)

## Review Loop

- Round 1 findings: Security found release hook atom creation and unbounded `use` includes; performance found unbounded duplicate custom-file reads; Elixir found inaccurate nil ownership counts and conflated parse/execution failure reporting.
- Round 1 fixes: Release hooks now accept only existing compiled atoms; top-level and composed scenarios share a cumulative 5 MB budget and depth limit 20; nil ownership references are omitted from aggregates; parse and execution failures report distinct bounded results and accurate partial-mutation state. All three reviewers confirmed no remaining findings.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
