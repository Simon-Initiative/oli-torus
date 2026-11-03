# Phase 2 Execution Record

Work item: `docs/exec-plans/current/features/audit-log-expansion`
Phase: `2` (MER-6112, PR-02), design `design/pr-02-boundary-and-ci-with-audited-user-deletion-pilot.md`

## Scope from plan.md
- Boundary enforcement and CI with one audited user-deletion pilot, built on PR-01.
- Current authorization: checkpoint A only, then pause for owner review. No commits or publication authorized.
- Existing branch: `sub-task/MER-6112-boundary-and-ci-with-audited-user-deletion-pilot`; predecessor `sub-task/MER-6111-event-contracts-partitioned-storage`, inspected baseline `a3218dc90c55a2bd79515fee86f078b5cced555e`.

## Implementation Blocks
- [x] Checkpoint A implementation: Boundary dependency/topology scoped to private audited account modules, real positive/negative compiler fixtures, forced CI compilation. Owner review is pending; checkpoint B is not authorized yet.
- [ ] Checkpoint B: audited application command, authorization, transaction, replay, and internal mutation.
- [ ] Checkpoint C: LiveView/caller migration and removal of the actorless delete API/manual capture.
- [ ] Checkpoint D: final verification, performance evidence, review, and closure.

## Test Blocks
- [x] Preparation on 2026-11-02: `mix deps.get`; `gleam build --target erlang` to supply missing runtime artifacts; `mix compile` passed. This was baseline preparation, not Boundary proof.
- [x] Design validation: design and full work-item validators plus requirements reference validation passed. Nested checks covered 40 requirements and 105 criteria; statuses/proofs unchanged.
- [x] Scoped dev compilation: `mix compile --warnings-as-errors` passed. The earlier nested topology failed on legacy cross-layer calls; the owner then explicitly narrowed enforcement, as recorded below.
- [x] `MIX_ENV=test mix compile --force --warnings-as-errors` passed (2,002 application Elixir files). Dependency warnings remain separate from application Boundary validation.
- [x] `elixir scripts/check_audit_boundary.exs` passed in dev: forced real-project baseline, allowed facade/internal/legacy calls, seven individual forbidden cases, and a successful recovery compile after every forbidden case.
- [x] `MIX_ENV=test elixir scripts/check_audit_boundary.exs` passed with the same cases plus the compiled `LiveComponentTests` caller (eight forbidden cases).
- [x] `MIX_ENV=playwright mix compile --force --warnings-as-errors` passed (1,952 application Elixir files).
- [x] Explicit `mix format --check-formatted` over every changed/new Elixir file and compiler fixture passed; `git diff --check` passed; the three edited workflow files passed YAML parsing.
- [x] Re-verification after the `Oli.Mix` simplification (2026-11-03): forced `--warnings-as-errors` compilation passed in dev, test, and playwright; `elixir scripts/check_audit_boundary.exs` passed in dev (9 forbidden cases) and test (10 forbidden cases, adding `LiveComponentTests`), with a successful recovery compile after each; `mix format --check-formatted`, `git diff --check`, and YAML parsing of the three workflow files passed.
- [x] Fixture runner timing on the owner's machine (2026-11-03): dev forced compile 58 s plus runner 75 s; test forced compile 56 s plus runner 82 s. The runner would add about 3.5 minutes to each `build.yml` run.
- [x] Owner decision on 2026-11-03: the runner and fixtures served as a one-time proof of the configuration and are removed from the repository and CI. CI enforcement is the forced `--warnings-as-errors` compilation in `build.yml`, which fails on any forbidden reference. Comments in `lib/oli/accounts/audited.ex` and on the legacy `check: [in: false]` boundaries warn against weakening the configuration. A new module outside every boundary already fails CI through Boundary's `unclassified_module` warning.
- To recover the runner and fixtures: `git checkout 8fc4be1a9c -- scripts/check_audit_boundary.exs test/fixtures/audit_boundary`, then restore its steps in `.github/workflows/build.yml` from the same commit.
- No application startup, test alias, database access, or migration was used for checkpoint A.
- [ ] Later checkpoints: targeted application/transport tests, real concurrency and replay, affected/full regressions.

## Work-Item Sync
- [x] Owner-requested simplification on 2026-11-03: removed the redundant `Oli.Mix` boundary and classified all eleven tasks directly into `Oli`. Added a Mix task facade call to the allowed fixture and forbidden Mix task fixtures for both private modules. Verified on 2026-11-03 (see Test Blocks). No index changes or commits.
- [x] FDD, plan, and detailed design reconciled with the owner-approved narrow scope. Full work-item validator and workflow YAML syntax checks passed. Final formatting and diff-whitespace checks are recorded below.
- [x] Owner narrowed Boundary on 2026-11-03 to the private account mutation/replay modules. Existing context relationships remain unrestricted; only `delete_user` will migrate. The audited boundary is independent (`top_level?: true`); legacy targets permit incoming calls while all callers retain outgoing checks. This supersedes the proposed legacy `dirty_xrefs` inventory.
- [x] Test policy clarified on 2026-11-03: unrelated fixtures and technical cleanup need no added audit events; generic catalog tests remain in PR-01; targeted coordinator tests prove real atomicity and event semantics. Represented product actions in Scenarios remain audited.
- [x] `automation_teardown` explicitly inventoried as E2E fixture cleanup, not migrated or given a new audited command in this slice. Its existing API-key/name/password controls and deployed-route limits are documented in the design.
- `handoff.md` is intentionally untracked and untouched. It must never be included in a commit without the owner's explicit approval.
- All Mix commands require scoped escalation. Any migration/reset, including the `mix test` alias, needs owner approval and a `pg_dump -Fc` backup under `~/db_backups/`; test database is `oli_test`.

## Review Loop
- Checkpoint A: `harness-review` with three dedicated reviewers following `docs/CODEREVIEW.md`, each reading only its assigned security, performance, or Elixir checklist. No actionable findings.
- Security verified the independent audited boundary has no ignored ancestor and legacy callers retain outgoing checks. Runtime authorization, atomicity, and replay remain for checkpoint B.
- Performance review found no business-path changes. Residual CI cost: forced compilation in dev/test plus each runner's isolated baseline; measure GitHub Actions duration when publication is authorized.
- Elixir review found no actionable issues; the final test fixture result and Playwright compilation passed after review.
- Review must be repeated against the actual command/transport implementation in later checkpoints.

## Requirements Verification
- The compiler results above establish the static private-module portion of FR-036 / AC-094, AC-095 for this checkpoint. They do not complete the broader requirement: transaction/replay and removal of the old delete route remain later. Requirements statuses/proofs are not promoted yet.
- Actual configuration: `Oli.Accounts.Audited` is independent and exports only its root. `Oli`, `OliWeb`, `ECL.Constellation`, and compiled `LiveComponentTests` allow legacy incoming calls but check outgoing references. Mix tasks explicitly classify directly to `Oli`; other ordinary modules follow their namespace. No `dirty_xrefs` or protected incoming exemptions.
- At checkpoint A, fixture calls to generated `__info__/1` verified both real private modules without production probe functions. The import fixture used an additional private, fixture-only module. Static metadata probes never executed; later command tests must exercise real behavior.
- Coverage limits: arbitrary dynamic calls, direct SQL, runtime-loaded `.exs` modules, and protocol implementations left unclassified by Boundary are outside this compiler guarantee. No repository-wide write interception or audit generation is claimed.

## Done Definition
- [ ] Phase tasks complete.
- [ ] Tests and verification pass.
- [ ] Review completed and findings addressed.
- [ ] Final work-item validation passes.
- [ ] Owner accepts each checkpoint; commits and publication receive separate explicit approval.
