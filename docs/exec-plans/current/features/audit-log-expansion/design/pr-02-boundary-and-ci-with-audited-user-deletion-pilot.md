# PR-02 Boundary and CI with Audited User Deletion - Detailed Design

Source Artifacts:
- PRD: `docs/exec-plans/current/features/audit-log-expansion/prd.md`
- FDD: `docs/exec-plans/current/features/audit-log-expansion/fdd.md`
- Plan: `docs/exec-plans/current/features/audit-log-expansion/plan.md` (Phase 2, MER-6112)
- Scope: `docs/exec-plans/current/features/audit-log-expansion/jira-subtasks.md` (PR-02)
- Inventory: `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md` (W02), `docs/exec-plans/current/features/audit-log-expansion/caller-inventory.tsv`
- Predecessor: `docs/exec-plans/current/features/audit-log-expansion/design/pr-01-event-contracts-partitioned-storage.md`, `docs/exec-plans/current/features/audit-log-expansion/phase-1-execution.md`

Status: implementation authorized through checkpoint A on 2026-11-03, after the owner asked to continue following the test-policy clarification. Source inspected at `a3218dc90c55a2bd79515fee86f078b5cced555e`. The design was prepared on 2026-11-02; implementation evidence belongs in `phase-2-execution.md`. Later checkpoints retain their owner-review pauses. Technical test teardown is explicitly distinguished from administrative deletion (section 4.5).

## 1. Slice Summary

Make user deletion an audited application command and prove the dependency boundary before extending it to other domains. Today `Accounts.delete_user/1` calls `Repo.delete/1`; `UsersDetailView` records `user_deleted` afterward and ignores the capture result. Replace that split with authorization, persisted-state capture, deletion, and the required event in one transaction.

In scope:
- `Oli.Accounts.Audited` as the shared facade, with unexported `Oli.Accounts.Audited.Mutations` inside its boundary.
- Existing account-admin/system-admin deletion through the user-detail LiveView and application callers; removal of `Accounts.delete_user/1` and the LiveView's manual capture.
- Serializing concurrent deletions of the same user through the target row lock, so a repeated attempt appends nothing.
- Boundary classification limited to the audited account internals, allowed/forbidden compilation fixtures, and forced compilation in CI.
- Transaction, authorization, historical identity, failure, concurrency, transport, and compatibility tests. Implementation evidence goes in `phase-2-execution.md`.
- An explicit inventory classification for technical test cleanup, so its direct writes are neither hidden nor mistaken for administrative commands (section 4.5).

Out of scope: a replay protocol (owner decision, 2026-11-03; see section 4.3), author deletion, other account lifecycle actions, authentication, general account field migration, new transport endpoints, a general operation registry, async orchestration, additional storage migrations, Audit Log UI redesign, and automatic retention. Existing audit storage and the remaining legacy producers stay compatible. No partial feature deployment is implied.

## 2. Requirements Coverage

These are design mappings, not implementation proof. Keep `requirements.yml` at its existing statuses with no fabricated proof entries. Record executed commands, revisions, and proof links in `phase-2-execution.md`; keep requirement and ticket codes out of code/test comments.

| Requirement / criteria | This slice's responsibility and planned proof |
| --- | --- |
| FR-003 / AC-008, AC-009 | One deletion/event transaction; authorization, domain failure, injected audit insert failure, and enclosing-Multi rollback tests |
| FR-003 / AC-010 | Canceling the confirmation writes nothing; an absent target, including a repeated attempt, is not a new successful deletion |
| FR-004 / AC-011, AC-012, AC-014 | Caller matrix, one semantic event, removal of manual capture, concurrent deletions of one user commit exactly one event |
| FR-004 / AC-013 | No bulk account-deletion endpoint exists in the inspected routes. No bulk protocol is introduced; future bulk commands need target-specific event keys |
| FR-007 / AC-024 | Deleted-user ID/name/email retained and searchable; application and LiveView tests. Author deletion remains PR-03 |
| FR-007 / AC-022, AC-023 | Creation/access/link/recovery remain PR-03; this pilot must not claim them complete |
| FR-029 / AC-069 | Preserve `user_deleted` contract, exactly once; preserve other legacy producer behavior through regression suites |
| FR-029 / AC-070, AC-071 | Existing flag/rollout and ClickHouse initiation semantics remain unchanged; run existing relevant compatibility tests |
| FR-035 / AC-092 | Recheck persisted administrator authorization inside the transaction; reject untrusted/malformed context and tampered target IDs |
| FR-035 / AC-091 | Existing system-admin Audit Log access remains unchanged; account-delete permission does not grant Audit Log access |
| FR-036 / AC-093 | Public command and composable Multi builder; raw mutation contains no auditing; existing reads remain available |
| FR-036 / AC-094, AC-095 | Compiled positive/negative fixtures in actual Torus configuration, removal of old API, classified direct/dynamic writes, legacy compatibility and documented checking limits |
| Common FR-001 / AC-001 through AC-004 | Actor versus affected user, persisted snapshots, UTC timestamps, one committed semantic success |
| Common FR-030 / AC-072 through AC-074 | Minimal projections, safe errors/logs, durable identities, secret-marker tests |
| Common FR-038 / AC-099 through AC-101 | Per-checkpoint evidence, affected regressions and required review; broader integration gates remain later |
| Common FR-039 / AC-102, AC-103 | Targeted delete latency/query-count and safe-failure evidence; migration evidence remains PR-01 |

### Caller and write inventory

The supplied lexical inventory is a starting point. Design inspection followed the user-delete calls, account changesets, route permissions, Scenario user handler and dynamic hooks, MCP registration, Repo delete sites, and deletion foreign keys. Checkpoint A must preserve compiler-derived dependency evidence; checkpoint C must update this action inventory against the final diff.

| Current path | Classification and treatment |
| --- | --- |
| `lib/oli/accounts.ex`, `delete_user/1` | Raw public shortcut; remove, do not retain an actorless compatibility wrapper |
| `lib/oli_web/live/users/user_detail_view.ex`, `delete_account` | Production UI caller; migrate to the facade, remove `log_admin_action/4` for this action |
| `test/oli/accounts_test.exs`, user deletion test | Public behavior test; supply an authorized context and assert deletion plus persisted evidence |
| `test/oli_web/controllers/page_delivery_controller_test.exs`, skipped account-deletion scenario | Update the user-deletion call even though the test is skipped; preserve its existing skip and author-deletion behavior. Use a separate live administrator, not the author deleted earlier in the test |
| `lib/oli/automation_setup.ex`, `teardown_user/4` | Technical automation cleanup: validates account credentials/name, removes `StudentResponse` rows, then calls `Repo.delete!`. Explicitly excluded from administrative deletion; see section 4.5 |
| `lib/oli_web/controllers/api/automation_setup_controller.ex`, `/api/v1/automation_teardown` | Adapter used by E2E teardown; protected by an automation-enabled API key. No change proposed in this slice |
| `lib/oli/scenarios/directives/user_handler.ex` | Creates accounts; no deletion directive found in `DirectiveTypes`/engine. Creation stays PR-03. Compiled Scenario fixtures still must fail on private mutation references |
| `lib/oli/scenarios/directives/hook_handler.ex` | Uses `apply/3` for trusted hooks. Inspect hook callers; do not describe dynamic dispatch as compiler-enforced or introduce a global Scenario exemption |
| `lib/oli/mcp/server.ex`, registered tools/resources | Activity/content tools; no account-delete tool registered. No new MCP endpoint |
| Accounts token deletion; `UserAssentAuth.delete_identity_providers/2`; `MCP.Auth.revoke_token/1` | Delete tokens/provider links, not user rows; later account/auth/credential coverage |
| `Accounts.update_user/2` and `User.noauth_changeset/2` | Updates do not hard-delete users; no deleted/tombstone attribute is cast. `hidden` and other account fields remain explicitly unmigrated PR-03 work; they are not certified as audited by this pilot |
| User schema association cleanup and database cascades | Internal effects of one user deletion, not additional account-deletion events. Preserve current Ecto association behavior and FK policies |
| `Accounts.delete_author/1` | PR-03; `users.author_id` is nilified by the inspected migration, not cascaded into user deletions |
| Direct Repo deletion in unrelated test cleanup, including `secure_assessment_admission_test.exs` | Fixture cleanup, not product behavior. Do not migrate unrelated fixtures or reproduce their committed-row leakage in new concurrency tests |
| Operator SQL and arbitrary runtime module calls | Outside Boundary's static guarantee; inspect supported repository paths and document the limit rather than claiming runtime prevention |

The broad delete search found the automation writer that the `delete_user` symbol search missed. Its explicit disposition is technical fixture cleanup, with evidence and limits in section 4.5. Repeat searches for aliases, pipelines, Repo/Multi deletes, direct SQL, and runtime invocation when implementation is complete; an empty symbol search alone is not closure evidence.

## 3. Responsibilities & Boundaries

### Proposed topology

Use Boundary `~> 0.12.0` with the exact release captured in `mix.lock`, `runtime: false`, and no environment-only restriction that leaves production compilation unable to expand `use Boundary`. Prepend `:boundary` to the existing compiler list, preserving Phoenix LiveView, Gleam, and the runtime staging compiler. Confirm compatibility on the repository's Elixir 1.19 / OTP 28 toolchain at checkpoint A.

The owner narrowed the scope on 2026-11-03: protect the private audited account modules without introducing restrictions between existing contexts. `Oli.Accounts.Audited` therefore becomes an independent top-level boundary, despite its nested namespace. Its root is public and its internal modules are not exported. Boundary reports violations as warnings; CI must use warnings-as-errors. [Boundary module documentation](https://boundary.hexdocs.pm/Boundary.html), [compiler documentation](https://boundary.hexdocs.pm/Mix.Tasks.Compile.Boundary.html).

| Boundary / module | Configuration and responsibility |
| --- | --- |
| `Oli` and `OliWeb` | `deps: [Oli.Accounts.Audited]`, `check: [in: false]`; preserve unrestricted incoming legacy calls while retaining outgoing checks |
| `Oli.Accounts.Audited` | `top_level?: true`, `exports: []`; both checks enabled, public facade and private implementation |
| `Oli.Accounts.Audited.Mutations` | Ordinary private module owned by the audited boundary; raw deletion only |
| `Oli.Application` | Remains part of `Oli`; no additional startup boundary |
| Mix tasks | Explicitly classified directly into `Oli`; reuse its existing rules without a separate task boundary |
| `ECL.Constellation` and compiled `LiveComponentTests` | Explicit boundaries with the same compatibility settings; no outgoing-check exemption |
| Other compiled test/seeding modules | Existing `Oli.*`/`OliWeb.*` namespace classification applies; Scenario callers remain checked |
| Protocol/generated modules | Record actual compiler coverage and tracer limits; no claim of unrestricted runtime enforcement |

`check: [in: false]` applies only to legacy targets. It does not disable their outgoing checks. The audited boundary has neither an ignored ancestor nor an incoming exemption because `top_level?: true` makes it independent. Callers may depend on its facade but cannot call its unexported internals. Internal modules may call each other: this is module-boundary enforcement, not a rule restricting calls to one particular function or caller module.

### Classification gate

The first compilation of the earlier nested design reported existing `Oli` to `OliWeb` and `OliWeb` to `ECL.Constellation` references. The owner explicitly excluded policing those relationships from this PR. Preserve those calls through the compatibility configuration above, without a growing `dirty_xrefs` list or broad context refactoring.

The configuration is accepted only after real positive and negative compiler fixtures prove it once at checkpoint A (see the execution record). Never export `Mutations`, exempt its incoming calls, disable caller outgoing checks, or add protected modules to `dirty_xrefs`. Verify that legacy cross-context calls still compile. This scope decision supersedes the earlier proposed exact legacy exception inventory; only `delete_user` is migrated in this PR.

Public `Oli.Auditing.build/2` and `append/3` remain the storage API. The pilot coordinator owns domain semantics; it does not introduce a generic callback orchestration framework. `LegacyAdapter` continues serving other producers. Remove this pilot's manual capture, but retain its legacy event mapping during the transitional PR because existing reader/contract fixtures still use it; do not claim the adapter itself enforces domain authorization.

## 4. Interfaces & Signatures

### 4.1 Public administrator command

```elixir
@type delete_result :: %{user_id: pos_integer()}

@type delete_error ::
        :invalid_request
        | :unauthorized
        | :not_found
        | :delete_failed
        | :nested_transaction
        | Oli.Auditing.Error.t()

@spec delete_user(Oli.Auditing.Context.t(), pos_integer()) ::
        {:ok, delete_result()} | {:error, delete_error()}

@spec delete_user_multi(
        Ecto.Multi.t(),
        Ecto.Multi.name(),
        Oli.Auditing.Context.t(),
        pos_integer()
      ) :: Ecto.Multi.t()
```

`delete_user/2` owns `Repo.transaction/1` and returns a small result instead of the deleted `%User{}`. This refines the FDD's illustrative result: the production caller uses only success/failure; its existing flash/navigation stays the same. It refuses an already-open transaction with `:nested_transaction`; composing callers use `delete_user_multi/4` so their outer transaction owns rollback and post-commit effects.

The Multi builder puts the safe result at the supplied name and uses tuple-prefixed private step names. It never commits. Reusing a step name is a programming error. A later failing outer step rolls back the deletion and event. Callers must not return a Multi error tuple from a transaction callback as though it were success.

The administrator entry accepts only a valid `Context` for an authenticated author, a positive integer user ID, a non-nil valid UUID operation ID, and supported source/correlation values. No client-supplied actor ID, role, audit sink, version, skip flag, or result payload is accepted by the transport. Because Elixir structs are not capabilities, the application trusts authenticated adapter construction and separately reloads authorization; it does not claim that a forged in-process struct establishes identity.

Inside the transaction, load the author with `FOR SHARE`; require a current account-admin or system-admin role, confirmed email, and an unlocked account, matching the route's authenticated-account-admin policy. Missing/revoked/locked actors receive `:unauthorized`. Rebuild the actor snapshot from that persisted row while retaining the trusted context's operation/source/parent IDs. Concurrent role or lock updates wait until the decision commits; later attempts see the change.

### 4.2 Internal mutation and event

```elixir
@spec Oli.Accounts.Audited.Mutations.delete_user(%Oli.Accounts.User{}) ::
        {:ok, %Oli.Accounts.User{}} | {:error, term()}
```

Only the coordinator calls this unexported module. It receives a freshly locked persisted user, invokes Ecto's existing delete behavior, and performs no auditing, authorization, or transaction ownership. Preserve association deletions and database FK actions; do not replace it with bulk SQL that skips Ecto cleanup, or add new destructive cascade policy to make blocked deletions succeed.

Build one existing `user_deleted` event with `Auditing.build/2`, then append with `Auditing.append/3` in the same Multi:

| Attribute | Value |
| --- | --- |
| Actor | Persisted authorized author, separate from affected user |
| Entity / affected | `{:user, user.id, safe_identity}` / `{:user, user.id}` |
| Snapshot | Only `id`, `name`, `email` from the locked row; no whole-account serialization |
| Event key / outcome | `account:primary:deleted` / `:succeeded` |
| Source / operation / parent | Trusted context |
| Details | Existing allowed `email`, `name`, `deleted_by` projections; no password/hash, account state, identity-provider data, or submitted attrs |
| Changes | Empty lifecycle changes, consistent with the current deletion example; snapshot supplies the applicable before-side identity |
| Scope | No invented project/section/institution. User deletion is global; `lti_institution_id` is not blindly treated as the audit institution FK |
| Times | Existing PR-01 `build/2` behavior |

Expected domain/constraint failures map to safe command errors; audit errors retain the existing safe `Oli.Auditing.Error`. Do not inspect rejected user changesets or raw PostgreSQL error details into logs. A rescued database error must lead immediately to transaction rollback, not another query in an aborted transaction. Unexpected programming errors still propagate after rollback; do not silently convert them to success.

### 4.3 Concurrency and repeated attempts

Owner decision, 2026-11-03: this pilot implements no replay protocol. MER-6066 requires no duplicate events, not retry receipts, and user deletion is naturally idempotent. The earlier proposal (operation advisory lock, all-partition completion lookup, `:already_applied` and `:operation_conflict`) is withdrawn; the FDD (section 7.1) assigns replay to asynchronous and external workflows, starting with PR-04.

1. Begin the transaction and load/authorize the actor under its shared row lock.
2. Load the user `FOR UPDATE`; absence returns `:not_found`. Then delete, build, append, and commit.

Concurrent deletions of the same user, from a double submission, a retry, or two administrators, serialize on the user row. The winner commits the deletion and one event; the others wait, find no user, and return `:not_found` without writing anything. A failed, unauthorized, or canceled request leaves no event, and a rolled-back attempt can simply be repeated. Every supported writer of this command uses the same transaction.

### 4.4 LiveView integration

Keep the current modal's appearance and flow. On confirmation, delete the user bound in `socket.assigns.user`, ignoring any client-submitted ID that does not match it, and build a fresh trusted context from the authenticated author. Do not preload the target outside the transaction. `{:ok, _}` keeps the existing success flash/navigation; `:not_found` and other errors use the existing failure flash. A repeated confirmation after a successful deletion therefore reports not found, as it does today. Remove the manual `log_admin_action/4`. Recheck actor authorization inside the coordinator even if HTTP route plugs already passed.

A fresh mount after deletion continues to show the existing not-found behavior. There is no new client storage or idempotency endpoint.

### 4.5 Technical test teardown exclusion

`automation_teardown` cleans up disposable accounts/course data created by the automation setup service. It is not the administrative user-delete command and not a seed operation. The Playwright client `assets/automation/src/systems/torus/tasks/AutomationSetupTask.ts`, `teardownAutomationCourse/3`, calls it with the setup response's generated accounts and credentials; E2E suites invoke that helper during cleanup, including `afterAll`. This caller evidence changes the initial classification based only on its direct Repo write.

Keep `AutomationSetup.teardown_educator/2`, `teardown_learner/2`, their private `teardown_user/4`, and the corresponding API adapter unchanged in PR-02. Record them as technical fixture cleanup excluded from this pilot's administrative-event policy. Do not introduce `delete_automation_user`, broaden system-actor authorization, or add cleanup audit events merely because a test account is physically deleted. This classification is proposed as part of the owner-reviewed design, not a claim that the broad original inventory already documented it.

The existing API key check is in `Oli.Plugs.ValidateAPIKey` / `Interop.validate_for_automation_setup/1`; name/password validation is in `AutomationSetup.validate_user/4`. These are the actual controls, not proof of account provenance. The route is not limited to `MIX_ENV=test`, so do not describe it as technically inaccessible in deployed instances. The exclusion applies to this identified fixture lifecycle, not all API deletions, Scenarios, or system actors. If a product flow starts using this endpoint for ordinary account administration, it must be brought through the audited application policy.

This does not exempt represented business actions exercised by tests: clicking an administrative delete in Playwright must still emit the normal event. Existing `test/oli/automation_setup_test.exs` and `test/oli_web/controllers/api/automation/automation_setup_controller_test.exs` remain the cleanup behavior/authorization references; do not modify them solely to satisfy audit cardinality for this excluded cleanup. No new Boundary exemption is needed: they must still be unable to call the private audited mutation statically.

## 5. Data Flow & Edge Cases

The administrator path is: modal confirmation → audited facade → transaction → current actor authorization → locked user → raw Ecto deletion → safe event build/append → commit → flash/navigation. No notification/cache effect currently belongs to `Accounts.delete_user/1`; do not add one. Composed callers keep their own effects after their outer commit.

| Situation | Required result |
| --- | --- |
| Fresh authorized deletion | User and existing cascaded data removed, one v2 success event, `:deleted` |
| Audit validation/insert or missing-partition failure | User and cascaded rows restored by rollback; no new success; safe audit error |
| FK/domain failure | Existing delete semantics preserved; no event and no partial association cleanup |
| Concurrent or repeated deletion of the same user | One deletion and one event; the others return `:not_found` and write nothing |
| Current actor revoked, locked, unconfirmed, or deleted | `:unauthorized` before target access |
| Absent target | `:not_found`, no success event |
| Actor/user identity updated before execution | Persisted locked identity supplies the new event; UI copies are ignored |
| Actor renamed after deletion | Historical snapshots stay unchanged |
| Outer Multi fails after this operation | Roll back user deletion and event; the deletion can later be attempted again |
| Same user ID and author ID | Distinct typed identities; no cross-type cleanup or attribution |
| Generic account update | Remains PR-03 scope; cannot invoke this private delete through the removed API |
| Dynamic call/direct SQL | Not prevented by Boundary; supported-path inventory and behavioral tests remain required |

No new migration is planned. Preserve PR-01's schema/indexes and append-only rules. Do not rely on a unique `(operation_id, event_key, inserted_at)` constraint: PR-01's physical schema deliberately has no such deduplication index. An older edge-case sentence in its design mentions one; this slice follows its physical-schema section and actual migration, and relies on the user row lock instead.

## 6. Test Plan

### 6.1 Compiled enforcement and CI

Prove the configuration once at checkpoint A with a database-free Boundary verification runner (`scripts/check_audit_boundary.exs`) and controlled source fixtures under `test/fixtures/audit_boundary/` (outside normal `elixirc_paths`). The runner and fixtures are not kept in the repository or CI; the owner decided on 2026-11-03 that a one-time proof, recorded in the execution record, is enough. The configuration modules carry comments warning against weakening it. The runner must test the actual project definitions and pinned dependency. Use a disposable source/build copy or equivalent isolated overlay that preserves the real Mix configuration; do not modify the working tree while another compile runs. Reuse fetched dependencies without network installation in the fixture runner. Capture output and report a concise pass/failure.

For each relevant environment, first force a clean successful application compilation. Then compile one negative fixture at a time and require both a nonzero exit and the Boundary diagnostic naming the forbidden caller/callee; syntax errors, missing deps, and ordinary compiler warnings are not a passing negative test. Finish with a successful positive compile to rule out stale manifests.

| Fixture | Expected |
| --- | --- |
| Read-context consumer calls existing read API and audited facade | Success |
| `OliWeb` consumer calls facade | Success |
| Compiled `Oli.Scenarios` consumer calls facade | Success |
| Same consumers call `Accounts.Audited.Mutations` directly, through an alias/import, or a captured static function | Boundary failure |
| Consumer calls private `Accounts.Audited.Replay` (checkpoint A only; the module was removed with the replay protocol) | Boundary failure |
| In-boundary coordinator calls private mutation | Success |
| Compiled test-support consumer attempts private call | Boundary failure in test environment |
| Arbitrary `.exs` test or dynamic `apply/3` | Documented coverage limit; not claimed as a protected compile fixture |

Add `--force` to existing warnings-as-errors project builds in `.github/workflows/build.yml`, `.github/workflows/pr-playwright.yml`, and `.github/workflows/nightly-playwright.yml`. The main build's forced test compilation is the CI enforcement: any forbidden reference becomes a warning and fails the build. Playwright compilation checks its actual environment. The fixture runner does not run in CI. Keep workflow branch filters unchanged: a draft based on `sub-task/MER-6111-event-contracts-partitioned-storage` still requires manual local checks. Do not broaden container/release packaging or disable caches to conceal compiler-manifest problems.

`test/support/*.ex` is compiled in `MIX_ENV=test`; most `.exs` tests, runtime-loaded Scenario hooks, and migrations are not part of the normal application compiler pass. Factories remain suitable for unrelated setup. Do not put a forbidden reference in an ordinary `.exs` test and call that proof of enforcement. Protocol/macro/generated-code limits must be recorded from the actual compiled inventory.

### 6.2 Behavioral and regression tests

Test policy, clarified before implementation: unrelated fixtures and technical cleanup do not need audit events or audited coordinators. PR-01 already owns the generic valid/invalid catalog and insert tests; do not duplicate them for every existing domain test. PR-02 adds focused tests of the coordinator's real mutation/event transaction and its supported transport. Tests of pure internal behavior can stay at that layer. Scenarios representing in-scope product actions still use the real audited entry points; there is no global test-environment audit bypass. This follows `informal.md`, "Tests, factories, Scenarios, and Playwright".

Proposed new suites: `test/oli/accounts/audited_test.exs` and `test/oli/accounts/audited_concurrency_test.exs`. Use existing account and LiveView suites for regression rather than duplicating all account tests.

- Exercise real successful deletes for both account-admin and system-admin; deny content-admin, ordinary author, user, system context, malformed context, and stale/revoked/locked/unconfirmed actor.
- Assert actor/affected separation, persisted target identity, one event, safe details/search text, event-time identity after rename/deletion, and absence of marker secrets in payloads/errors/captured logs.
- Cover an actual FK failure and existing cascading association behavior. Insert a test-only failure trigger, scoped to the tested operation, inside a rollback-isolated database test to force a real audit insert failure after deletion. No production sink override. Assert both the user and cascaded rows survive; capture intentional logs.
- Exercise the Multi builder inside an outer failing transaction and verify no independent commit. Verify the convenience command rejects nested use.
- Cover a missing user, a repeated deletion after success, and retry after a rolled-back attempt.
- Use independent database sessions with an explicit barrier to prove waiting and exactly one committed success when two calls delete the same user concurrently. A shared Sandbox connection is not concurrency proof. Also test a role-revocation race.
- Confirm/cancel the real LiveView modal; reject tampered target IDs and demotion after mount. Verify existing success/navigation and failure flashes, and that no manual capture duplicates the event.
- Preserve audit readers/catalog/legacy adapter regression coverage. No renamed/released event names or blanket removal of compatibility fixtures.

Concurrency tests run `async: false` in `oli_test`. When committed fixtures are necessary for independent sessions, isolate them with tracked IDs, stop and await all tasks/connections, and clean up in `try/after` before releasing the test. Remove only those test events using a scoped transaction-local append-only override; remove only owned account/dependent fixtures. Assert cleanup and propagate failures. Do not reproduce the known `unboxed_run` leak, leave orphaned sessions, or disable global Logger output. No new shared test bypass.

Planned affected suites after test authorization: `test/oli/accounts_test.exs`, the new audited suites, `test/oli_web/live/users`, `test/oli_web/controllers/page_delivery_controller_test.exs`, `test/oli/auditing_test.exs`, `test/oli/auditing`, and `test/oli_web/live/admin/audit_log_live_test.exs`; existing feature-flag audit regressions for compatibility. Automation cleanup suites remain unchanged and run as part of the full regression suite. Record skipped tests as skipped, not proof.

Because Boundary changes compilation/test support classification, run the full suite at the final gate. Investigate failures; rerun the known institutions/brands/publishers/deployments failures with `mix test --failed`. Record both results; do not label every failure as known flakiness.

### 6.3 Database, performance, and validation procedure

All Mix commands use scoped escalated permissions. Every migration/reset requires prior owner approval and a `pg_dump -Fc` backup under `~/db_backups/`, including migrations implicit in this repository's `mix test` alias. Before any approved test run, verify the effective `MIX_ENV=test` database is `oli_test`; `DATABASE_URL` takes precedence and `DB_NAME` is not the test-database selector. Record only safe host/database metadata, never credentials. Run no migration merely to prepare the design or compiler fixtures.

At checkpoint D record delete latency and query count at a documented volume. Measure serialized waiting separately from uncontended overhead. Compare p50/p95 and query count with the raw-delete baseline; use the FDD's proposed overhead budget `max(10 ms, 20% of baseline p95)` as a review threshold, not an asserted production SLA. Keep the targeted evidence here; PR-07 owns the known admin list/search performance work. No extra schema/index or benchmark framework without measured need.

Run design/work-item validation and requirements-reference validation. Supplement the traceability tool with nested criteria/reference checks because its historical top-level-only limitation is recorded in the PRD. A passing document validator does not establish transaction, compiler, or security correctness.

## 7. Risks & Open Questions

- **Technical cleanup distinction:** section 4.5 records the narrowly identified automation teardown exclusion for owner review. It must not become a general unaudited deletion API or an exemption for represented administrative actions in tests.
- **Compiler topology — checkpoint A gate:** the independent audited boundary and legacy compatibility settings need actual Boundary compiler evidence. Stop before expanding domain coverage if forbidden calls compile. The source inventory is not that evidence.
- **Runtime enforcement limit:** Boundary protects static module use, not every Repo write, privileged SQL, arbitrary atom/module construction, or in-process actor forgery. Retain authenticated adapters, command authorization, caller inventory, and tests.
- **Authorization locking:** enforce one lock order (actor, then target user) and current actor permissions. Query timeout cancellation must abort the transaction.
- **Delete semantics:** existing restrictive FKs may legitimately block some accounts. Preserve failure and rollback instead of adding cascades in an auditing slice.
- **Test isolation:** independent-session tests can leak committed rows and trigger existing list-test flakiness. Cleanup ownership, task shutdown, and clean ExUnit output are acceptance conditions.
- **Scope size:** one implementation PR, with internal checkpoints; no additional pilot, split, branch, or PR is implied by the automation finding or dependency inventory.

## 8. Definition of Done

### Design gate

- [x] Requirements and existing caller evidence mapped, with uncovered/deferred scope distinguished.
- [x] Public/private interfaces, authorization, concurrency, error, and transport behavior specified (replay withdrawn by owner decision, 2026-11-03).
- [x] Test strategy, compiler limitations, database safety, and compatibility defined.
- [x] Design and full work-item validation pass for this document.
- [x] Owner authorizes continuing with checkpoint A after the technical-cleanup and test-policy clarification (2026-11-03).

Design verification on 2026-11-02: `validate_work_item.py --check design --file <this design>` and `--check all` passed; `requirements_trace.py --action master_validate --stage plan_present` passed. An additional nested check verified 40 unique requirement IDs and 105 unique criterion IDs, valid design references, unchanged `verified_plan` statuses, and empty proof lists. No implementation tests or migrations ran for this design.

### Implementation checkpoints after approval

1. **A — Boundary topology and compiler proof.** Install/configure Boundary, classify callers without restricting existing context relationships, add the private module/facade shell and compile fixtures, wire forced CI compilation. Record compiler evidence and pause for owner review before implementing the mutation.
2. **B — Audited application command.** Implement authorization, row locking, raw mutation, event Multi, safe results/errors, and meaningful transaction/concurrency tests. Preserve the documented technical cleanup exclusion; pause with evidence.
3. **C — Caller migration.** Migrate the LiveView, remove the old public delete/manual capture, update all owned application tests, verify transport and secret behavior, and close the caller inventory. Pause for review.
4. **D — Final verification.** Format, forced dev/test/Playwright compilation as applicable, affected/full suites, delete latency evidence, `harness-review` (security, performance, Elixir, plus UI if warranted by actual changes), and work-item validation. Follow `docs/CODEREVIEW.md` for dedicated reviewers when running the review. Resolve findings and record residual limits before declaring PR-02 complete.

Maintain `phase-2-execution.md` in the style of Phase 1: implementation/test blocks, work-item sync, review rounds, requirement proof, and done definition. Distinguish proposed, executed, passing, and owner-accepted gates. A checkpoint is not permission to commit.

No commit, push, PR creation, GitHub/Jira comment, or change to `handoff.md` is part of this design action. Every commit requires the owner's approval of its exact file list and message; `handoff.md` always requires its own explicit approval. Publication remains a later agreed action. PR-02's future draft base is `sub-task/MER-6111-event-contracts-partitioned-storage`, with the required stacked notice on #7019 and merge-only ancestry.
