# Phase 2 Execution Record

Work item: `docs/exec-plans/current/features/audit-log-expansion`
Phase: `2` (MER-6112, PR-02), design `design/pr-02-boundary-and-ci-with-audited-user-deletion-pilot.md`

## Scope from plan.md
- Boundary enforcement and CI with one audited user-deletion pilot, built on PR-01.
- Current authorization: checkpoint A only, then pause for owner review. No commits or publication authorized.
- Existing branch: `sub-task/MER-6112-boundary-and-ci-with-audited-user-deletion-pilot`; predecessor `sub-task/MER-6111-event-contracts-partitioned-storage`, inspected baseline `a3218dc90c55a2bd79515fee86f078b5cced555e`.

## Implementation Blocks
- [x] Checkpoint A implementation: Boundary dependency/topology scoped to private audited account modules, real positive/negative compiler fixtures, forced CI compilation. Accepted by the owner and committed on 2026-11-03.
- [x] Checkpoint B (2026-11-03): `Oli.Accounts.Audited.delete_user/2` and `delete_user_multi/4` lock the user `FOR UPDATE`; delete through `Mutations.delete_user/1`; and append `user_deleted` with `Auditing.append/3` in the same transaction. A restrictive foreign key returns `:delete_failed`. `Audited` gained `check: [out: false]`: Boundary rejects the `Oli` ↔ `Audited` dependency cycle, and incoming checks still protect `Mutations`. Owner review pending; checkpoint C not started.
- [x] Checkpoint C (2026-11-03): `UsersDetailView` `delete_account` builds `Context.for_actor(current_author, source: :ui)` and calls `Accounts.Audited.delete_user/2` with `socket.assigns.user.id`; a submitted ID that does not match the displayed user gets the existing failure flash without deleting. Removed the manual `log_admin_action/4` and `Accounts.delete_user/1`. Updated `accounts_test.exs` (raw-delete test removed) and the skipped `page_delivery_controller_test.exs` scenario. Caller inventory closed in the design (section 2). The shared `DeleteAccountModal` is unchanged; the author detail view still uses `Accounts.delete_author/1` (PR-03). Owner review pending.
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
- [x] Owner decision on 2026-11-03: the command does not authorize the actor. MER-6066 and AC-092 require keeping existing authorization, which for this action is the route's `:require_authenticated_account_admin` plug. The initial in-transaction author reload (`FOR SHARE`, role/confirmation/lock checks, persisted actor snapshot) was removed, with its tests (role, confirmation, lock, deleted actor, renamed actor, concurrent role revocation). The `@doc` states that `user_id` is the user to delete and that callers authorize. The general rule in the FDD (sections 3, 7.1, 12) and `plan.md` now says each action keeps its existing authorization where it already lives and coordinators add no new checks.
- [x] Checkpoint B database preparation: `pg_dump -Fc` of `oli_test` to `~/db_backups/oli_test_pre_MER-6112-B_20261103_135331.dump` before the first `mix test` (its alias drops, creates, and migrates `oli_test`); `DATABASE_URL` unset, so the database was `oli_test` on localhost.
- [x] First run, before the authorization decision: `mix test test/oli/accounts/audited_test.exs test/oli/accounts/audited_concurrency_test.exs`, 15 tests, 0 failures. After removing authorization: the same suites plus `test/oli/accounts_test.exs` and `test/oli_web/live/users`, 189 tests, 0 failures, clean ExUnit output, and no leftover users, authors, or `user_deleted` events. The coordinator suite covers success and event contents, invalid requests, missing user, repeated deletion, foreign-key failure, injected audit insert failure (test trigger, captured log without the user's email), nested transaction refusal, and Multi composition with a failing later step. The concurrency suite uses independent connections: two concurrent deletions commit one deletion and one event, and the other returns `:not_found`.
- [x] Regression: `mix test test/oli/accounts_test.exs test/oli_web/live/users test/oli/auditing_test.exs test/oli/auditing test/oli_web/live/admin/audit_log_live_test.exs test/oli/accounts`: 6 doctests, 404 tests, 0 failures.
- [x] Boundary after `check: [out: false]`: a temporary `Oli` module calling `Mutations.delete_user/1` reported `forbidden reference to Oli.Accounts.Audited.Mutations` and `mix compile --warnings-as-errors` exited 1; after removing it, compilation exited 0.
- [x] Checkpoint C tests: `admin_live_test.exs` asserts one `user_deleted` event with the logged-in administrator as actor and `:ui` source, and that a tampered ID deletes nothing. `mix test test/oli_web/live/admin_live_test.exs test/oli/accounts_test.exs test/oli/accounts test/oli_web/live/users test/oli_web/controllers/page_delivery_controller_test.exs test/oli/auditing_test.exs test/oli/auditing test/oli_web/live/admin/audit_log_live_test.exs`: 6 doctests, 514 tests, 0 failures, 39 excluded (`:skip`, including the updated page-delivery scenario). No compiler warnings in the changed test files; `MIX_ENV=test mix compile --warnings-as-errors` passed.
- [ ] Checkpoint D: full suite, forced dev/test/playwright compilation, latency evidence, review.

## Work-Item Sync
- [x] Owner-requested simplification on 2026-11-03: removed the redundant `Oli.Mix` boundary and classified all eleven tasks directly into `Oli`. Added a Mix task facade call to the allowed fixture and forbidden Mix task fixtures for both private modules. Verified on 2026-11-03 (see Test Blocks). No index changes or commits.
- [x] FDD, plan, and detailed design reconciled with the owner-approved narrow scope. Full work-item validator and workflow YAML syntax checks passed. Final formatting and diff-whitespace checks are recorded below.
- [x] Owner narrowed Boundary on 2026-11-03 to the private account mutation/replay modules. Existing context relationships remain unrestricted; only `delete_user` will migrate. The audited boundary is independent (`top_level?: true`); legacy targets permit incoming calls while all callers retain outgoing checks. This supersedes the proposed legacy `dirty_xrefs` inventory.
- [x] Owner decision on 2026-11-03: no replay protocol in this pilot. MER-6066 requires no duplicate events, not retry receipts; the transaction and the user row lock already guarantee one event when deletions of the same user repeat or run concurrently. Removed `Oli.Accounts.Audited.Replay` and reconciled the PR-02 design (sections 4.3, 4.4, 5, 6), the FDD (section 7.1 and related rows), `plan.md`, `jira-subtasks.md`, and two PR-01 design sentences. Replay remains only for asynchronous and external workflows, designed in PR-04. Mentions of `Replay` in earlier checkpoint A entries are historical. The MER-6112 Jira "Done when" line is updated to match.
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
- The compiler results above establish the static private-module portion of FR-036 / AC-094, AC-095 for this checkpoint. They do not complete the broader requirement: the transaction and removal of the old delete route remain later. Requirements statuses/proofs are not promoted yet.
- Actual configuration: `Oli.Accounts.Audited` is independent and exports only its root. `Oli`, `OliWeb`, `ECL.Constellation`, and compiled `LiveComponentTests` allow legacy incoming calls but check outgoing references. Mix tasks explicitly classify directly to `Oli`; other ordinary modules follow their namespace. No `dirty_xrefs` or protected incoming exemptions.
- At checkpoint A, fixture calls to generated `__info__/1` verified both real private modules without production probe functions. The import fixture used an additional private, fixture-only module. Static metadata probes never executed; later command tests must exercise real behavior.
- Coverage limits: arbitrary dynamic calls, direct SQL, runtime-loaded `.exs` modules, and protocol implementations left unclassified by Boundary are outside this compiler guarantee. No repository-wide write interception or audit generation is claimed.

## Done Definition
- [ ] Phase tasks complete.
- [ ] Tests and verification pass.
- [ ] Review completed and findings addressed.
- [ ] Final work-item validation passes.
- [ ] Owner accepts each checkpoint; commits and publication receive separate explicit approval.
