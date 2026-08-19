# UpGrade Data-Capture Parity - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity/fdd.md`
- Requirements: `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity/requirements.yml`

## Scope
Restore native A/B testing data capture to at least the post-processing capability of UpGrade v0.33.0. The implementation must preserve a complete section-wide evaluated-activity stream in ClickHouse `raw_events`, add assignment-backed causal evidence in `experiment_attributions`, and make both projections reconstructable from durable S3 xAPI across direct, Lambda, replay, and backfill paths.

Guardrails:
- Keep `Oli.Experiments` authoritative for assignment, scope, selected-branch attribution, exposure, reward, and policy semantics; analytics code must not reinterpret these rules.
- Keep section-wide activity outcomes analytically distinct from causal experiment attribution. An absent attribution must never remove an applicable activity-attempt row.
- Preserve both weighted-random assignment scopes and intervention-scoped Thompson Sampling without changing allocation, reward eligibility, posterior mutation, or runtime idempotency.
- Use immutable attempt/publication/revision provenance. Do not consult mutable authoring content or trust client-supplied experiment identity.
- Make ClickHouse schema changes additive and nullable. Do not populate, derive, or mutate historical rows, and do not add a PostgreSQL migration.
- Do not add UI, an export API/job, a feature flag, historical UpGrade migration, content republishing, or stronger xAPI delivery guarantees.
- Preserve the existing asynchronous publication lookup behavior; exact attempt-time publication is deferred to MER-5889.
- Exclude names, emails, LMS identifiers, raw responses, free-form content, and unbounded policy state from the new evidence, queries, and telemetry.

## Clarifications & Default Assumptions
- The input path resolves to this directory; `plan.md` is created beside `prd.md`, `fdd.md`, and `requirements.yml`.
- `enrollment_id` is the pseudonymous participant key; the same user in two sections is two participants.
- Missing historical `assignment_scope` is interpreted as `intervention`; fields newly introduced by this work remain null when absent from persisted evidence.
- The host hash is lowercase SHA-256 over the exact persisted JSON statement, and the attribution hash is lowercase SHA-256 over `raw_event_hash <> ":" <> attribution.key`.
- Compatibility windows are half-open: `assigned_at <= observed_at < analysis_end`. Pausing does not split the window, and exposure is not an inclusion gate for section-wide outcomes.
- Continuous correctness is `score / out_of`; storage preserves null/raw values and the compatibility query alone normalizes zero, invalid, or missing values to `0.0` with a bounded data-quality classification.
- The first supported navigation and nested-content producers must be confirmed during implementation. A producer is enabled only if it has a stable host-event identity and immutable containment provenance; activity-attempt compatibility coverage is mandatory regardless.
- The production Lambda target topology must be confirmed before its projection is changed, but the normalized logical row contract is topology-independent.
- Statements durably persisted in S3 are replayable. The existing pre-persistence crash window is observable but unrecoverable in this work.
- Local MinIO and ClickHouse execution is a required acceptance gate. QA execution is optional and depends on separately supplied authorized environment configuration.

## Phase 1: Contract Inventory And Golden Evidence Baseline
- Goal: Freeze the shared wire, projection, hash, privacy, and supported-producer contract before changing runtime or analytical paths (FR-008, FR-009, FR-011, FR-012; AC-017, AC-018, AC-021, AC-022, AC-023).
- Tasks:
  - [ ] Inventory current assignment/exposure/outcome/reward/policy attribution fields, xAPI schemas, direct uploader mapping, Lambda mapping, backfill mapping, and ClickHouse columns.
  - [ ] Confirm the MER-5883 assignment-scope contract and record the historical missing-scope interpretation without changing assignment behavior.
  - [ ] Confirm the Lambda target topology and enumerate the first-release activity, part, media, navigation, nested-content, and asynchronous producers that meet stable identity and immutable provenance requirements.
  - [ ] Write one versioned projection specification covering JSON paths, types, nullable/default behavior, allowed `role`/`attribution_type` pairs, occurrence timestamps, host/attribution hashes, and privacy allowlists.
  - [ ] Add golden JSONL fixtures for no attribution, both weighted-random scopes, Thompson outcome/reward/policy evidence, multiple attributions, historical missing fields, malformed attribution, and byte-sensitive hash cases.
  - [ ] Define normalized expected raw-event and attribution rows for use by Elixir, Python, replay, SQL, and acceptance tests.
- Testing Tasks:
  - [ ] Add schema/semantic fixture checks that reject malformed role/type combinations and forbidden privacy fields while accepting historical evidence.
  - [ ] Prove hash fixtures use exact persisted bytes and deterministic attribution keys.
  - Command(s): `mix test test/oli/analytics/xapi/schema_validator_test.exs test/oli/experiments/xapi/attributions_test.exs`
  - Command(s): `python3 -m pytest cloud/xapi-etl-processor/tests`
- Definition of Done:
  - The field mapping, role semantics, timestamp semantics, null/default rules, supported producers, hashes, and privacy allowlists have one reviewable contract and golden examples.
  - No implementation path needs to invent analytics semantics independently.
- Gate:
  - Gate A passes when golden fixtures validate, all supported producer prerequisites are identified, and security review approves the bounded payload contract.
- Dependencies:
  - MER-5883 assignment-scope behavior and the existing native experiment/xAPI foundation.
- Parallelizable Work:
  - Elixir schema fixtures and Python fixture harness work can proceed concurrently after the mapping specification is drafted.

## Phase 2: Assignment-Backed Provenance Resolution And XAPI Enrichment
- Goal: Resolve causal relationships from scoped assignments and immutable realized content, then attach bounded evidence without suppressing host statements (FR-001 through FR-005, FR-007, FR-011, FR-012; AC-001 through AC-011, AC-014 through AC-016, AC-021, AC-023).
- Traceability: AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, and AC-015 are exercised explicitly by the assignment reuse, scope, exposure, containment, asynchronous provenance, and outcome/reward separation work in this phase.
- Tasks:
  - [ ] Add a documented, set-based `Oli.Experiments.resolve_event_attributions/2` boundary (or equivalent) that accepts validated delivery scope plus bounded event provenance and returns normalized facts by stable event key.
  - [ ] Resolve section, enrollment, project, assignment, condition, assignment scope, actual intervention, placement, selected option, page/activity revision, and attempt provenance exclusively from server-side state and persisted `resource_attempts.content`.
  - [ ] Support canonical `experiment_controlled` and historical `upgrade_decision_point` groups, multiple decision points, nested selected content, and zero/multiple proven relationships.
  - [ ] Preserve the original `assigned_at` on reuse, nullable assignment-level intervention for `section_enrollment`, and distinct intervention-specific exposure keys/provenance.
  - [ ] Extend `Oli.Experiments.XAPI.Attributions` with the generic `interaction` role and the bounded assignment, occurrence, placement, selected-alternative, revision, attempt, score, and denominator fields from the shared contract.
  - [ ] Enrich supported activity, part, media, navigation, nested-content, and asynchronous statements; always emit the ordinary host statement when no attribution is found or safe attribution resolution fails.
  - [ ] Preserve independent outcome, accepted reward, and policy-update entries and timestamps; weighted-random outcomes must not create rewards or posterior updates.
  - [ ] Add bounded telemetry for resolution status/duration, query count, matched assignments, emitted roles/scopes, and safe failure reasons.
  - [ ] Add or update public API documentation for every new or modified public function.
- Testing Tasks:
  - [ ] Cover both assignment scopes, reuse, distinct exposures, multiple decision points, in/out-of-branch events, historical aliases, asynchronous reconstruction, and current-deployment publication behavior.
  - [ ] Cover activity/part/media/navigation/nested events, multiple attributions, raw outcome values and timestamps, and strict separation of weighted-random outcomes from Thompson reward/policy evidence.
  - [ ] Assert one bounded assignment query per scope batch, bounded attribution cardinality, tenant scoping, and privacy exclusions.
  - Command(s): `mix test test/oli/experiments test/oli/analytics/xapi`
- Definition of Done:
  - Supported host statements carry only assignment-backed, immutable-provenance relationships; out-of-branch and unrelated events remain unattributed.
  - Existing assignment, exposure, reward, policy, and host-statement behavior remains intact.
- Gate:
  - Gate B passes when AC-001 through AC-011 and AC-014 through AC-016 have focused proof, query-count checks pass, and MER-5889 behavior is documented rather than changed.
- Dependencies:
  - Gate A contract and fixtures.
- Parallelizable Work:
  - Attribution resolver implementation, schema evolution, and telemetry instrumentation can be split after shared fact structures and allowlists stabilize.

## Phase 3: Additive ClickHouse Schema And Direct Projection
- Goal: Materialize one logical host row plus zero or more joined causal rows without mutating historical evidence (FR-005, FR-006, FR-008 through FR-012; AC-010 through AC-013, AC-017 through AC-023).
- Traceability: AC-019 is proven by the one-host-row/zero-or-more-attribution-row projection and `raw_event_hash` join tests in this phase.
- Tasks:
  - [ ] Generate additive ClickHouse up/down migrations using the repository migration mechanism; add only nullable scalar columns and scoped-query indexes required by the contract.
  - [ ] Ensure migration SQL contains no data update, derived default, replay, or historical population operation and leaves all new fields null on existing rows.
  - [ ] Extend `raw_events` activity-attempt projection with stable enrollment, section, attempt, score, denominator, evaluation time, and raw-event hash fields required by the section-wide compatibility stream.
  - [ ] Extend `experiment_attributions` with bounded causal fields and role/type validation, preserving nullable assignment-level intervention identity.
  - [ ] Update direct ingestion to calculate hashes from exact persisted statement bytes and emit one host row plus one row per valid attribution.
  - [ ] Keep malformed attribution diagnostics independent from raw host-event recovery.
  - [ ] Add indexes/order-aware fields for tenant/section/time filtering and `raw_event_hash` joining without introducing unscoped analytical access.
- Testing Tasks:
  - [ ] Migrate representative historical rows up and down and prove their prior values remain logically unchanged with nulls in all new columns.
  - [ ] Insert unattributed, multi-attributed, malformed, duplicate, and replayed statements and assert correct raw/attribution row cardinality and joins.
  - [ ] Verify immediate-dedup query behavior with `FINAL` or equivalent `argMax` logic.
  - Command(s): `mix test test/oli/analytics/xapi/clickhouse_uploader_test.exs test/oli/analytics/clickhouse`
- Definition of Done:
  - ClickHouse represents the complete section-wide activity stream and the causal overlay as separate, hash-joined projections.
  - Historical rows remain untouched and rollback removes only the additive schema introduced by this work.
- Gate:
  - Gate C passes when migration up/down, historical preservation, raw-row inclusion, causal left-join, and duplicate convergence tests pass.
- Dependencies:
  - Gate A projection contract; Phase 2 enriched fixtures must be stable before final integration assertions.
- Parallelizable Work:
  - Migration authoring and direct transformer implementation can proceed concurrently against the golden expected rows.

## Phase 4: Lambda, Replay, And Backfill Parity
- Goal: Make every durable ingestion path produce the same logical rows and deterministic identities (FR-009, FR-010, FR-011, FR-013; AC-018 through AC-024).
- Tasks:
  - [ ] Update the Python Lambda row builder at the confirmed production topology to implement the shared raw/attribution mapping and hash rules.
  - [ ] Update Elixir S3 replay/backfill transformation and SQL generation to implement the same mapping without querying mutable content or PostgreSQL analytics state.
  - [ ] Preserve raw host-event recovery when attribution validation fails and emit bounded path/version diagnostics.
  - [ ] Ensure direct retry, SQS retry, replay, and overlapping backfill converge through deterministic event and attribution identities.
  - [ ] Add normalized cross-language comparison tooling that runs the same golden JSONL through direct, Lambda, and replay/backfill preparation.
  - [ ] Document path/version identifiers and safe mismatch diagnostics without learner identifiers or raw content.
- Testing Tasks:
  - [ ] Compare normalized fields, nulls/defaults, roles, timestamps, and hashes across all projection implementations.
  - [ ] Cover old statements, malformed extensions, whitespace/order-sensitive JSON, duplicates, retries, and partial projection recovery.
  - [ ] Run package-native Python tests/formatting and targeted uploader/backfill ExUnit tests.
  - Command(s): `python3 -m pytest cloud/xapi-etl-processor/tests`
  - Command(s): `mix test test/oli/analytics/xapi/clickhouse_uploader_test.exs test/oli/analytics/backfill`
- Definition of Done:
  - Direct, Lambda, replay, and backfill produce matching logical evidence for every golden statement and retrying a durable statement does not create a second logical row.
- Gate:
  - Gate D passes when cross-language golden parity and replay/idempotency tests prove AC-018 through AC-020.
- Dependencies:
  - Gate A fixtures, Gate C schema, and stable Phase 2 producer fields.
- Parallelizable Work:
  - Lambda and backfill implementations can proceed concurrently; parity comparison is the convergence gate.

## Phase 5: Compatibility Query, Diagnostics, And Operational Artifacts
- Goal: Prove the UpGrade-compatible shape from ClickHouse alone and make evidence gaps diagnosable (FR-006, FR-008, FR-012 through FR-014; AC-012, AC-013, AC-017, AC-023 through AC-025).
- Tasks:
  - [ ] Add parameterized, versioned ClickHouse SQL that filters by explicit tenant/section or experiment and time before joining, selects `activity_attempt` host rows, left-joins causal attribution by ordered `raw_event_hash`, and emits enrollment, condition, observed timestamp, and correctness.
  - [ ] Implement half-open assignment windows, earliest completion/archive/request cutoff semantics, pause behavior, unattributed-row inclusion, and documented zero/invalid/missing normalization.
  - [ ] Add expected-result fixtures/assertion tables tied to the deterministic acceptance seed and demonstrate that out-of-branch rows remain in the compatibility stream without causal attribution.
  - [ ] Add parameterized diagnostic SQL for assignment without exposure, exposure without later evidence, expected-but-missing outcome attribution, reward without projection, orphan hashes, duplicates, lag, path/version disagreement, data quality, and assignment imbalance.
  - [ ] Add bounded AppSignal/Telemetry signals for attribution/projection status, failures, counts, durations, ingestion lag buckets, and path/version while excluding participant identity from routine dimensions.
  - [ ] Validate partition pruning, tenant/time predicates, ordered hash joins, and dedup strategy on representative multi-section data.
  - [ ] Document the compatibility schema, occurrence-time meanings, crash-window limitation, diagnostic interpretation, and future export boundary.
- Testing Tasks:
  - [ ] Add SQL structure/parameter-safety checks and fixture-based expected-result verification suitable for ordinary CI without claiming live ClickHouse execution.
  - [ ] Exercise all required diagnostic conditions against representative rows.
  - [ ] Review query plans for bounded scans and material regression in ingestion/query behavior.
  - Command(s): `mix test test/oli/analytics test/oli/experiments`
- Definition of Done:
  - Repository-owned SQL reconstructs the historical enrollment/condition/timestamp/correctness shape without PostgreSQL or mutable content and retains causal, reward, and policy evidence separately.
  - Required missing-evidence and path-parity conditions are operationally diagnosable.
- Gate:
  - Gate E passes when AC-012, AC-013, AC-017, AC-024, and AC-025 are proven by fixtures, SQL checks, diagnostics, and query-plan review.
- Dependencies:
  - Gates C and D.
- Parallelizable Work:
  - Compatibility SQL, diagnostic SQL, telemetry, and documentation can proceed concurrently against the same fixture contract.

## Phase 6: Deterministic Scenario And Local Durable-Path Acceptance
- Goal: Exercise real authoring, delivery, persistence, projection, and query behavior through local MinIO and ClickHouse (FR-001 through FR-014; AC-001 through AC-026).
- Tasks:
  - [ ] Use the `build_scenario` skill to add deterministic `Oli.Scenarios` YAML and a companion ExUnit runner for real authoring, both Alternatives spellings, publishing, participating sections, and stable evidence labels/identifiers.
  - [ ] Cover two enrollments for one user, repeated page views, both weighted-random scopes, Thompson Sampling, multiple decision points/activities, in/out-of-branch interactions and outcomes, and reward/policy evidence.
  - [ ] Use `extend_scenario` only if current directives cannot express required workflows or evidence inspection; keep domain setup fixture-free.
  - [ ] Add an environment-parameterized xAPI inspection/validation script or task that discovers scenario JSONL objects in MinIO/S3, validates every statement, checks roles/fields/privacy exclusions, and records object keys and statement hashes.
  - [ ] Add a safe developer automation entrypoint that accepts explicit identifiers/time bounds and chains scenario seed, MinIO discovery/validation, ingestion readiness, and ClickHouse compatibility/diagnostic checks.
  - [ ] Leave inspectable evidence on failure and stop immediately on missing/invalid durable xAPI rather than compensating downstream.
  - [ ] Add an environment-parameterized operator runbook with prerequisites, safety checks, commands, expected results, evidence template, cleanup guidance, and sign-off checklist reusable in authorized QA without embedded credentials.
  - [ ] Execute the acceptance flow locally and capture identifiers, object keys/hashes, projected row evidence, parity results, diagnostics, and query results.
- Testing Tasks:
  - [ ] Validate and run the scenario runner and all script/task fixture tests.
  - [ ] Inspect persisted MinIO JSONL before triggering/waiting for projection, then run the compatibility and diagnostic SQL against local ClickHouse.
  - [ ] Replay the durable statements and prove host/attribution logical row counts remain stable.
  - Command(s): `mix test test/scenarios/<upgrade_data_capture_parity_runner>.exs`
  - Command(s): `<developer acceptance entrypoint> --environment local --section-id <id> --from <timestamp> --to <timestamp>`
- Definition of Done:
  - Deterministic scenario coverage proves AC-001 through AC-026 across the real workflow.
  - Local MinIO contains valid inspectable statements, local ClickHouse contains matching deduplicated projections, and the compatibility query returns the expected fixture shape.
  - The checked-in runbook and automation can repeat the process using explicit authorized environment configuration.
- Gate:
  - Gate F is the required feature-acceptance gate and passes only after successful local scenario seeding, durable xAPI inspection, ClickHouse projection/diagnostics, replay idempotency, and captured evidence. QA execution is not required.
- Dependencies:
  - Gates B through E and locally available MinIO/ClickHouse services.
- Parallelizable Work:
  - Scenario authoring, inspection tooling, SQL assertions, and runbook drafting can overlap; the final acceptance run waits for all production and projection paths.

## Phase 7: Final Verification, Reviews, And Handoff
- Goal: Complete repository validation and provide auditable implementation evidence without expanding scope.
- Tasks:
  - [ ] Run focused and affected ExUnit suites, Python Lambda tests/formatting, scenario validation/runner, schema/semantic fixture checks, and SQL artifact checks.
  - [ ] Run `mix format`, package-native Python formatting, and `git diff --check`.
  - [ ] Apply `.review/security.md` to tenant scoping, authoritative provenance, SQL parameterization, credentials, privacy allowlists, logs, and telemetry.
  - [ ] Apply `.review/performance.md` to assignment query counts, attribution cardinality/payload size, ingestion batching, hashes, ClickHouse partitions/indexes/joins, and compatibility-query scans.
  - [ ] Apply `.review/elixir.md`, `.review/requirements.md`, and any Python/UI/TypeScript guidance warranted by the actual changed files; no frontend work is expected.
  - [ ] Verify all new or modified public APIs are documented and all known publication-provenance limitations point to MER-5889.
  - [ ] Assemble PR evidence: contract version, migrations, golden parity, targeted/full tests, local MinIO/ClickHouse acceptance record, diagnostic samples, security/performance findings, and deferred items.
  - [ ] Draft any needed Jira MER-5885 change exactly and obtain explicit user approval before using `jira` to write; read the issue back and correct formatting after any approved update.
  - [ ] Run requirements traceability and work-item validation commands.
- Testing Tasks:
  - [ ] Run the final targeted command set established by the changed-file inventory, followed by broader affected suites where practical.
  - [ ] Run all harness verification commands and retain their output in the implementation handoff.
  - Command(s): `mix test <targeted experiment, analytics, and scenario test paths>`
  - Command(s): `python3 -m pytest cloud/xapi-etl-processor/tests`
  - Command(s): `mix format`
  - Command(s): `git diff --check`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity --action verify_plan`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity --action master_validate --stage plan_present`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity --check plan`
- Definition of Done:
  - FR-001 through FR-014 and AC-001 through AC-026 have traceable automated, local-acceptance, review, or documentation evidence.
  - Formatting, security, performance, requirements, and harness gates pass; deferred publication provenance and optional QA execution are explicit.
- Gate:
  - Gate G passes when all required checks and the local durable-path acceptance record are complete and no unresolved scope or privacy issue remains.
- Dependencies:
  - Gates A through F.
- Parallelizable Work:
  - Security, performance, requirements, documentation, and handoff evidence reviews can proceed concurrently while the final automated suite runs.

## Parallelization Notes
- Phase 1 owns the shared contract; downstream implementations may scaffold in parallel but must not finalize divergent mappings before Gate A.
- After Gate A, the Elixir resolver/xAPI work, ClickHouse migration/direct projection, and Python/backfill fixture harnesses can be divided among independent changes with golden rows as the integration boundary.
- Phases 3 and 4 converge before compatibility SQL is accepted. Phase 5 may draft queries early, but Gate E depends on actual schema and parity behavior.
- Phase 6 scenario, inspection tool, automation, and runbook work can start once fixture identities are stable; its final live run waits for Gates B through E.
- Security and performance verification are distributed through every phase and repeated as final focused reviews rather than deferred entirely to Phase 7.
- No Jira write is implicit in this plan. Any substantive ticket update requires an exact draft and explicit user approval first.

## Phase Gate Summary
- Gate A: Shared xAPI/projection/hash/privacy contract and golden fixtures are complete.
- Gate B: Assignment-backed immutable-provenance resolution and xAPI enrichment pass behavioral, privacy, and query-count tests.
- Gate C: Additive ClickHouse migrations and direct projection preserve history and separate the section-wide stream from causal overlay.
- Gate D: Direct, Lambda, replay, and backfill mappings are logically identical and replay-idempotent.
- Gate E: Compatibility and diagnostic SQL prove export-ready semantics with bounded tenant/time queries.
- Gate F: Deterministic scenarios pass the required local MinIO-to-ClickHouse durable-path acceptance flow with captured evidence.
- Gate G: Automated suites, formatting, reviews, traceability, documentation, and final handoff all pass.
