# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/usage`
Phase: `1 - Characterize Naive Contracts and Establish Canonical Boundaries`

## Scope from plan.md

- Lock down existing naive behavior before provider extraction.
- Introduce canonical estimate and aggregate contracts.
- Add Section-owned dispatch without migrating production consumers.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [ ] Observability or operational updates when needed (planned for Phase 2 provider execution)

Implemented:

- Added `Oli.Delivery.Proficiency.Estimate` and `Aggregate` validated contracts.
- Added `Oli.Delivery.Proficiency` with Section-owned dispatch, integer-ID compatibility loading, model-option rejection, and explicit provider-unavailable behavior until Phase 2.
- Confirmed the twelve legacy Metrics proficiency functions return raw tuples, label strings, page/container maps, nested objective/student maps, distributions, and detailed student rows.
- Confirmed direct naive formula duplication remains in `ProgressProficiency` and `ProficiencyAssertion` for removal in later planned phases; Authoring Insights remains descriptive analytics and out of scope.
- Added focused comments/docs for model ownership, missing-versus-zero semantics, and canonical signal separation.

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Results:

- Phase 1 Gate A command: 38 tests, 0 failures.
- `mix format --check-formatted` on changed Elixir/test files: passed.
- `mix compile --warnings-as-errors`: passed.
- `git diff --check`: passed.

## Work-Item Sync

- [x] PRD, FDD, and plan reviewed for implementation alignment
- [x] No implementation divergence or new open question identified

## Review Loop

- Round 1 findings:
  - Security: no findings.
  - Performance: no findings.
  - Elixir: provider lookup could misclassify unloaded modules; constructors raised on unknown fields.
  - Requirements: Gate A overstated AC-003 and final adapter closure for AC-007 through AC-009; the raw tuple boundary was not explicitly documented.
- Round 1 fixes:
  - Load provider modules before callback checks.
  - Return explicit unknown-field validation errors from both constructors and add regression tests.
  - Document `raw_proficiency_per_learning_objective/2` as a naive-only compatibility API.
  - Correct Gate A traceability: Phase 1 establishes the baseline, Gate B proves adapter parity, and Gate D proves missing LKT dependency behavior.
- Round 2 findings:
  - Estimate missing required fields still raised because `struct!/2` enforced keys before validation.
  - The documented Gate A command omitted sibling facade/integration/naive-boundary test files, and successful provider delegation was not exercised.
- Round 2 fixes:
  - Use non-raising construction after explicit unknown-field validation and cover missing required fields.
  - Run every Phase 1 contract suite explicitly and add successful argument-preserving delegation tests for every facade operation and both models.
- Round 3 findings:
  - Production-named provider doubles in the facade tests could contaminate the shared test VM and mask the expected provider-unavailable path.
  - The Phase 1 facade task still carried an AC-003 annotation even though that missing-state behavior belongs to Gate D.
- Round 3 fixes:
  - Replace production-named doubles with isolated `Oli.Test.Proficiency.*Provider` modules selected through a test-only dependency mapping; serialize the configuration-changing tests and restore prior application configuration on exit.
  - Remove AC-003 from the Phase 1 facade task and retain its explicit Gate D ownership.
- Final re-review:
  - Elixir: no remaining findings.
  - Requirements: no remaining findings.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
