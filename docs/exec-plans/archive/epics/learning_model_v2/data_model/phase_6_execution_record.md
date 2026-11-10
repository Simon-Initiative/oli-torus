# Phase 6 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/data_model`
Phase: `6`

## Scope from plan.md

- Integrate and verify the complete behavior-neutral learning-model data foundation.
- Close migration, archive, startup configuration, staged-rollout, traceability, and review gates.
- Publish stable typed interfaces for the later `core_impl` and `usage` work items.

## Implementation Blocks

- [x] Core behavior changes
  - No new runtime behavior was required in Phase 6; the combined Phase 1–5 implementation was verified as one slice.
- [x] Data or interface changes
  - Added the downstream interface contract to `fdd.md`: Section-owned dispatch, publication-pinned typed Revision parameters, `0.0` cold-start semantics, and one `Oli.LearningModel.Config.fetch!/0` call per bulk operation.
- [x] Access-control or safety checks
  - Confirmed ordinary Project and Section changesets still ignore model-selection input and no authoring/delivery UI exposes selection or coefficient editing.
  - Confirmed no learner state, evidence, Snapshot Worker, Metrics, page/container aggregation, or Insights implementation entered this data-model work item.
- [x] Observability or operational updates when needed
  - Verified default and overridden startup logs and a controlled invalid-override startup failure naming `LKT_AOA_RHO`.

## Test Blocks

- [x] Tests added or updated
  - No new Phase 6 behavior test was necessary. Existing focused tests and documented hybrid checks provide proportionate proof for every acceptance criterion.
- [x] Required verification commands run
  - `mix test test/oli/learning_model test/oli/course_test.exs test/oli/clone_test.exs test/oli/delivery_test.exs test/oli/delivery/sections/blueprint_test.exs test/oli/resources_test.exs test/oli/publishing_test.exs test/oli/interop`
  - `mix test test/oli/sections_test.exs test/oli_web/controllers/open_and_free_controller_test.exs test/oli/scenarios/product_test.exs test/oli/scenarios/section_revise_test.exs test/oli/authoring/editing/adaptive_duplication_test.exs test/oli/publishing/unique_ids_test.exs test/oli/editing/activity_editor_test.exs test/oli/editing/container_editor_test.exs test/oli_web/live/ingest/ingestv2_test.exs`
  - `mix compile --warnings-as-errors`
  - `mix format --check-formatted`
  - Harness requirements master validation and work-item validation commands from `plan.md`.
  - `git diff --check`
- [x] Results captured
  - Integrated backend suite: 256 tests, 0 failures.
  - Supplemental prior-phase regression suite: 152 tests, 0 failures.
  - The suite emitted the repository's known asynchronous inventory-recovery ownership log but completed successfully.
- The full archive round-trip was rerun and its generated JSON assertions and imported records were inspected for an `:lkt_aoa` Project, divergent `:naive` Product, LO beta, two activity-part betas, and explicit `0.0`.

## Operational Verification

- The developer reset the local development database before implementation, applying the migration over the existing seed data.
- Read-only post-migration verification found one Project and one Section, both non-null and `:naive`; both semantic-value check constraints are installed.
- Four historical Revisions remained readable, including a pre-parameter Revision loaded as `learning_model_parameters: nil`.
- Default application startup logged `gamma=0.1`, `rho=1.0`, `recency_decay=0.9`, and `confidence_saturation=3.0`, all with default provenance.
- A short-lived application startup with representative overrides logged and returned `0.35`, `1.25`, `0.8`, and `4.0`, all with override provenance.
- Startup with `LKT_AOA_RHO=invalid` exited nonzero before serving and reported `LKT_AOA_RHO must be a finite number`.
- Source and diff inspection found no client asset using model selection, no coefficient editor, and no new proficiency/confidence persistence or calculation integration.

## Acceptance-Criteria Proof Map

- `AC-001` and `AC-002`: migration/schema tests plus the post-reset catalog and row verification above.
- `AC-003` through `AC-017` and `AC-019` through `AC-024`: the Phase 3–5 execution records and the integrated 256-test run.
- `AC-018`: automated missing-versus-explicit-zero persistence tests plus the FDD's documented `0.0` downstream cold-start contract; calculation remains intentionally owned by `core_impl`.
- `AC-025` through `AC-029`: config unit/subprocess tests plus the three startup checks above.
- `AC-030`: general-changeset negative tests and explicit source/UI/diff inspection.
- `FR-001` through `FR-009` and `AC-001` through `AC-030` are marked verified in `requirements.yml` with implementation and test proofs.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - No product or architecture decision changed. The FDD now makes the downstream consumption boundary explicit and Phase 6 plan tasks are reconciled with completed evidence.
- [x] Open questions added to docs when needed
  - No open question blocks this work item.
- Jira association: none was provided; no ticket was invented.

## Review Loop

- Round 1 findings:
  - Elixir, security, and performance reviews found no actionable implementation issue.
  - Requirements review found that `AC-018` overstated automated proof for the deferred runtime `0.0` calculation and that final plan/PRD/record completion state needed reconciliation.
- Round 1 fixes:
  - Changed `AC-018` to hybrid verification, added the FDD/Phase 6 proof, and explicitly separated the verified persistence/cold-start contract from calculation behavior owned by `core_impl`.
  - Reconciled the PRD, Phase 6 plan, requirements proof map, and this execution record.
- Round 2 findings:
  - Requirements re-review found no remaining actionable issue.
- Round 2 fixes:
  - None required.
- Residual operational risks:
  - The migration still requires brief bounded table locks; production deployment should retain normal lock monitoring and retry behavior.
  - No production-sized migration rehearsal or malicious oversized-archive stress test was performed. Parameter-envelope size limits remain a separate approved-contract decision.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
