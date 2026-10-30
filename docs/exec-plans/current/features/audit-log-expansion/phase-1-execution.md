# Phase 1 Execution Record

Work item: `docs/exec-plans/current/features/audit-log-expansion`
Phase: `1` (MER-6111, PR-01), design `design/pr-01-event-contracts-partitioned-storage.md`

## Scope from plan.md
- Event contracts, partitioned storage, central-history migration, and retirement of the legacy table.
- Implemented so far: checkpoint A (contracts). Checkpoints B (storage), C (migration), and D (evidence) are pending; checkpoint A is paused for owner review before any DDL.

## Implementation Blocks
- [x] Checkpoint A: `Oli.Auditing.Context`, `EntityId`, `Snapshot`, `Sensitive`, `Changes`, `EventCatalog` (`Contract`, `Definitions`, `Fields`, `Validation`); 25 families and 107 events with family, label, and description.
- [x] Checkpoint A: per-family change-field policies taken from the domain changesets (`Oli.Auditing.EventCatalog.Fields`).
- [x] Checkpoint A: field policy completeness (`test/oli/auditing/field_policy_drift_test.exs`, design section 4.3). `Fields.schema_sources/0` declares 33 domain schemas with the policies they feed, exclusions with reasons, and pseudo keys; every `Fields` policy is covered; the test adds the `redact: true` rule and `Oli.Auditing.FieldPolicyFixture`.
- [x] Checkpoint A: `Oli.Auditing.EventExamples` and `Oli.Auditing.EventReference` (test support); generated `docs/design-docs/audit-log-events.md`; `test/support/audit/released_event_names.txt`.
- [ ] Checkpoint B: migration create step, v2 `LogEvent`, `build/append/insert`, legacy adapter, readers, partitions and worker.
- [ ] Checkpoint C: copy, reconciliation, swap, `down/0`, roll-forward, rehearsal.
- [ ] Checkpoint D: benchmark, partition removal rehearsal, `evidence/pr-01-storage.md`.

## Test Blocks
- [x] Tests added: `test/oli/auditing/{event_catalog,contracts,context,changes,snapshot,entity_id,event_reference}_test.exs`.
- [x] Commands run: `mix format --check-formatted`; `mix compile --warnings-as-errors --force`; `mix test test/oli/auditing test/oli/auditing_test.exs` (4 doctests, 143 tests, 0 failures after review round 2); full `mix test` because shared test support changed: 30 doctests, 9999 tests, 4 failures, all four unrelated to auditing and passing on `mix test --failed` (timeout and ordering flakiness).
- [ ] Database-backed contract checks (insert and raw-SQL rejection per example) arrive with checkpoint B.

## Work-Item Sync
- [x] No divergence from the approved design so far. Implementation notes for review: contract validation lives in `EventCatalog.Validation` (pure) so the checkpoint B changeset can call it; the v1-only `assessment_setting_changed` example is documented as migrated history.

## Review Loop
- Round 1 findings (independent Elixir/security/performance review of checkpoint A): secret marker pattern accepted extra keys; account snapshots with `nil` name/email failed validation; secrets inside struct values not detected; validation could raise on string affected IDs, invalid UTF-8, or non-string keys; sensitive-key pattern gaps (`passcode`, `passphrase`, `*_key`, `jwks`, `bearer`, `otp`); missing fields recorded as explicit `null`; linear name lookups; errors on the wrong column; nested `case`; test gaps.
- Round 1 fixes: all twelve addressed. Exact marker comparison; snapshots built through `Snapshot.of/1`; `Changes.diff/3` normalizes values to JSON-native terms and `Changes.validate/2` rejects non-native values; validation returns errors for malformed input; extended pattern with `Fields.not_secret/0` for `auth_token_url` and `tool_jwk_id`; missing sides omitted; `EventCatalog.cast_name/1` map lookup; per-column errors; regression tests for each case.
- Cleanup pass (change-cleanup, smart mode): corrected the `Context.for_actor/2` spec, removed unused `Snapshot.fields/0` and `Changes.record_keys/0`, unified the type-name regex in `Validation`, replaced `if` and `then` in test support with multi-clause helpers, corrected the `Fields` moduledoc.
- Round 2 findings (independent Elixir/security/performance review): `validate/1` raised on struct snapshots, changes, or details, on non-string snapshot keys, on map or list entity types for account events, and on improper lists; invalid UTF-8 and over-long strings in entity IDs, snapshots, change values, and reference labels were accepted; non-positive actor and reference IDs were accepted; actor snapshots were not checked against the actor kind; `set` records without values were accepted; `diff/3` raised on non-string map keys and recorded decimal scale changes; the design listed snapshot fields without `key`; the drift test did not flag stale pseudo keys.
- Round 2 fixes: all addressed with regression tests. `Snapshot.valid_text?/1` (valid UTF-8, at most 255 characters) for snapshot values, entity IDs, and reference labels; struct and improper-list guards; `positive_id?` for actor and reference IDs; per-kind actor snapshot fields; at least one side for non-reset records; `Decimal.equal?/2` in `diff/3`; pseudo-key checks in the drift test. `changes` keeps no byte limit (documented in design section 4.3: only allowlisted contract fields can appear). Security and performance: no findings.

## Done Definition
- [ ] Phase tasks complete
- [ ] Tests and verification pass
- [ ] Review completed when enabled
- [ ] Validation passes
