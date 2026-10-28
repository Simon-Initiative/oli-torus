# Phase 2 Execution Record

Work item: `docs/exec-plans/current/features/preview-environment-tooling`
Phase: `2 - Build the Synchronous Scenario Release Interface`

## Scope from plan.md

- Add an environment-neutral seeding dispatcher with a `mix seed` development interface, a preview `bin/seed` release interface, and an immutable bundled registry.
- Keep compile-gated sources outside the recursively compiled `lib/` tree under `seeding/lib/`, compiled for development, preview, and test but excluded from production.
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

- `mix test test/oli/seeding/cli_test.exs test/oli/scenarios/seed_execution_test.exs test/oli/preview_qa_tools/build_policy_test.exs test/oli/scenarios/progress_simulation_scenario_test.exs` — 32 tests, 0 failures after the environment-neutral rename.
- `mix seed scenarios list` — passed in development and listed bundled metadata through `Oli.Seeding.CLI`.
- `MIX_ENV=preview mix release --overwrite` — passed; assembled the preview release with the executable `bin/seed` overlay backed by `Oli.Seeding.CLI`.
- `MIX_ENV=prod mix release --overwrite` — passed; assembled production release omits `bin/seed` and all `Oli.Seeding` modules.
- Enabled preview-release `bin/seed scenarios list` smoke test — passed and returned bundled metadata without parsing or executing YAML.
- `MIX_ENV=prod mix compile` — passed; the `Oli.Seeding.CLI` module and `Mix.Tasks.Seed` task are absent.
- `mix format`, `mix format --check-formatted`, and `git diff --check` — passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged (no divergence)
- [x] Open questions added to docs when needed (none)

## Review Loop

- Round 1 findings: Security found release hook atom creation and unbounded `use` includes; performance found unbounded duplicate custom-file reads; Elixir found inaccurate nil ownership counts and conflated parse/execution failure reporting.
- Round 1 fixes: Release hooks now accept only existing compiled atoms; top-level and composed scenarios share a cumulative 5 MB budget and depth limit 20; nil ownership references are omitted from aggregates; parse and execution failures report distinct bounded results and accurate partial-mutation state. All three reviewers confirmed no remaining findings.
- Round 2 findings: The unconditional release overlay left a broken `bin/seed` executable in production, and configured `default_admin` selectors did not re-check the system-admin role.
- Round 2 fixes: Non-preview release assembly now removes `bin/seed`; both configured-default author lookups require an active system administrator, with negative regression coverage.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
