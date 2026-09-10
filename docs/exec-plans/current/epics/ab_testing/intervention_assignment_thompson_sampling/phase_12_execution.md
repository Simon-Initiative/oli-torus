# Phase 12 Execution: Remove Decision-Point Algorithm Persistence

## Implementation

- Generated `priv/repo/migrations/20260813163458_remove_algorithm_from_experiment_decision_points.exs` with explicit reversible `up/0` and `down/0` behavior.
- Removed decision-point algorithm casting and persistence; the schema keeps a virtual derived field for internal policy dispatch.
- Updated authoring, activation, batch and single assignment, assessment reward handoff, reward mutation, telemetry, lazy placement discovery, and policy-state paths to use the owning experiment algorithm.

## Verification

- `mix format lib/oli/experiments.ex lib/oli/experiments/schemas/decision_point.ex priv/repo/migrations/20260813163458_remove_algorithm_from_experiment_decision_points.exs test/oli/experiments/configuration_test.exs`
- `mix compile` — passed.
- `mix test test/oli/experiments/configuration_test.exs test/oli/experiments/runtime_test.exs` — 46 tests, 0 failures.
- `mix test test/oli/delivery/experiments/assessment_reward_handoff_test.exs test/oli/delivery/experiments/reward_handoff_worker_test.exs test/oli/experiments/persistence_test.exs` — verifies reward handoff and physical single-column persistence.

## Requirements Trace

- FR-001 / AC-001: `ExperimentDefinition.algorithm` is the only persisted policy value; focused configuration and runtime tests prove coherent multi-point validation and dispatch.
