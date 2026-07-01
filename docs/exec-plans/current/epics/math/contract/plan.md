# Math Equality Contract And Numeric Evaluation - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/math/contract/prd.md`
- FDD: `docs/exec-plans/current/epics/math/contract/fdd.md`
- Requirements: `docs/exec-plans/current/epics/math/contract/requirements.yml`

## Scope

Deliver the shared Gleam equality contract and first numeric scalar evaluator for standard/basic page math evaluation. The plan covers the typed equality configuration model, durable JSON encode/decode, result diagnostics, standard response-rule numeric operator support, tolerance and precision options, representation constraints, cross-target verification, and optional thin Elixir/TypeScript wrappers.

Guardrails:
- Keep this work focused on equality only. Do not select feedback, scores, response matches, hints, targeted feedback, or activity lifecycle actions.
- Do not change production evaluator reducers in this work item.
- Do not change adaptive page evaluation. Existing behavior in `lib/oli/delivery/attempts/activity_lifecycle/adaptive_part_evaluation.ex` remains on the current adaptive branch and is not a parity target.
- Do not build authoring UI, delivery UI, database migrations, storage changes, feature flags, caches, background jobs, or production telemetry.
- Do not implement algebraic normalization, algebraic equivalence, expression sampling, exact-form evaluation, or unit conversion behavior in this work item.
- Do not duplicate equality behavior in Elixir or TypeScript. Torus boundaries should call the public Gleam API through thin wrappers.
- Preserve privacy by avoiding production logs or telemetry that include raw student answers or raw expected answers.
- In every phase that writes Gleam code, use liberal function-level and code-level comments to explain why a type, variant, numeric rule, JSON decision, tolerance branch, or legacy parity behavior exists. Every non-trivial public or internal Gleam function should have a comment explaining its intent and why it belongs at that layer. Add narrower line-level or block-level comments where an implementation detail is tricky, compatibility-driven, or likely to be misunderstood. Comments should capture intent and compatibility decisions, not restate obvious code.

## Clarifications & Default Assumptions

- The root persisted shape is planned as `equalityConfig`, backed by a Gleam root type such as `EqualitySpec`.
- Numeric expected values should be represented as strings in JSON so authored form is available for representation and precision checks.
- Phase 2 uses `gleam_json` for JSON parsing and encoding inside the shared Gleam equality boundary.
- Future non-numeric modes may be modeled in the type system now, but evaluating those modes should return a clear unsupported-mode result until later math roadmap features implement them.
- Legacy rule-string conversion is deferred to the later production evaluator integration work item.
- Jira tracking is available, but no Jira issue was provided with this work item.

## Phase 1: Equality Type Contract And Module Boundary

- Goal: Establish the shared Gleam equality type model and public API boundary before implementing JSON or numeric behavior. Covers FR-001, FR-002, FR-003, FR-007, AC-001, AC-004, AC-005, AC-007, AC-008, AC-019, and AC-020.
- Tasks:
  - [ ] Create the equality module structure under `gleam/src/math/equality/`.
  - [ ] Add core types for root equality spec, mode variants, numeric spec, expression spec placeholder, unit-aware spec placeholder, numeric comparisons, tolerance, representation, precision, range bounds, config errors, equality outcomes, and diagnostics.
  - [ ] Expose initial public functions through `gleam/src/torus_math.gleam` without exposing internal equality modules as the Torus stability boundary.
  - [ ] Ensure numeric comparison variants represent standard/basic page operators only: equal, not equal, greater than, greater than or equal to, less than, less than or equal to, between, and not between.
  - [ ] Add explicit unsupported-mode result types for expression and unit-aware modes.
  - [ ] Add function-level comments for every non-trivial Gleam function introduced in this phase, explaining the function's intent and layer responsibility.
  - [ ] Add code-level comments explaining why the ADT is shaped as sum/product types, why adaptive evaluation is excluded, and why unsupported modes are modeled before executable behavior exists.
- Testing Tasks:
  - [ ] Add compile-level or constructor tests proving representative equality specs can be built and invalid combinations are avoided by type shape where practical.
  - [ ] Add tests proving expression and unit-aware modes can be represented but do not imply executable support yet.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Equality type skeleton compiles on Erlang and JavaScript targets.
  - Public API placeholders exist through `torus_math.gleam`.
  - Adaptive page behavior is documented in code comments as out of scope.
- Gate:
  - Both Gleam target test commands pass before JSON encode/decode work begins.
- Dependencies:
  - PRD, FDD, and requirements are present and valid.
- Parallelizable Work:
  - Result/diagnostic type tests can be drafted while the config ADT is implemented.

## Phase 2: JSON Contract And Golden Fixtures

- Goal: Implement durable JSON encode/decode for the equality spec and establish fixtures as the storage compatibility contract. Covers FR-001, FR-007, FR-008, AC-002, AC-003, AC-019, AC-020, AC-021, AC-022, and AC-023.
- Tasks:
  - [ ] Decide and document the Gleam JSON implementation approach.
  - [ ] Add JSON encode/decode functions for the root spec, numeric comparisons, tolerances, representation constraints, precision constraints, and future mode placeholders.
  - [ ] Reject unsupported versions, unknown discriminators, missing required fields, invalid numeric option values, and contradictory structures.
  - [ ] Store numeric expected values as strings in JSON.
  - [ ] Add golden JSON fixtures for every public numeric config family and at least one unsupported future-mode fixture.
  - [ ] Expose `decode_equality_config`, `encode_equality_config`, and `validate_equality_config` through the public Gleam API.
  - [ ] Add function-level comments for every non-trivial Gleam encoder, decoder, and validation function, explaining intent and boundary behavior.
  - [ ] Add code-level comments explaining JSON versioning, discriminator choices, strict decode behavior, and why extra or unknown behavior should fail closed.
- Testing Tasks:
  - [ ] Add JSON round-trip tests for each fixture. Covers AC-002.
  - [ ] Add decoder rejection tests for malformed JSON, missing fields, unknown mode/comparison/tolerance/precision values, bad versions, and invalid numeric parameters. Covers AC-002 and AC-003.
  - [ ] Run both Gleam target suites.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - JSON fixtures define the initial `equalityConfig` contract.
  - Invalid JSON structures are rejected with structured errors.
  - Public JSON functions are available from `torus_math.gleam`.
- Gate:
  - Round-trip and rejection tests pass on both targets before numeric evaluation begins.
- Dependencies:
  - Phase 1 type model and public API.
- Parallelizable Work:
  - Fixture examples and rejection cases can be authored while encoders are implemented.

## Phase 3: Numeric Parsing And Standard Operator Evaluation

- Goal: Implement current standard/basic page numeric comparison semantics for scalar and range operators. Covers FR-003, FR-004, FR-009, AC-007, AC-009, AC-010, AC-011, AC-012, AC-024, AC-025, and AC-026.
- Tasks:
  - [ ] Implement numeric input parsing for Number input semantics, separate from expression parser numeric literal rules.
  - [ ] Preserve current supported notation for integers, decimals, leading-decimal values such as `.5`, negatives, and scientific notation.
  - [ ] Implement equal, not equal, greater than, greater than or equal to, less than, less than or equal to, between, and not between comparisons.
  - [ ] Implement inclusive and exclusive range bounds.
  - [ ] Preserve current reversed-bound behavior by comparing against min/max values.
  - [ ] Add equality result diagnostics for parse failure, value mismatch, and range mismatch.
  - [ ] Add function-level comments for every non-trivial numeric parsing and comparison function, explaining which standard/basic page behavior it preserves.
  - [ ] Add code-level comments explaining why Number input parsing intentionally differs from expression parsing and why adaptive numeric forms are excluded.
- Testing Tasks:
  - [ ] Add numeric evaluator tests for every standard response-rule operator. Covers AC-007 and AC-024.
  - [ ] Add range tests for inclusive, exclusive, inverse, boundary, and reversed-bound cases. Covers AC-010, AC-011, and AC-026.
  - [ ] Add parse tests for integer, decimal, leading-decimal, negative, and scientific notation. Covers AC-012.
  - [ ] Add tests or documentation assertions that adaptive numeric cases are excluded and remain on `AdaptivePartEvaluation`. Covers AC-008 and AC-025.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Standard/basic page numeric operators evaluate through the Gleam equality API.
  - Adaptive page numeric behavior is not represented as executable parity scope.
  - Operator and range behavior is covered on both targets.
- Gate:
  - Operator and range tests pass on both targets before tolerance and precision work begins.
- Dependencies:
  - Phase 2 JSON contract and typed numeric comparison variants.
- Parallelizable Work:
  - Operator tests and range tests can be authored in parallel after numeric result types stabilize.

## Phase 4: Tolerance, Precision, And Representation Constraints

- Goal: Add numeric tolerance, decimal precision, legacy significant-figure precision, and representation checks as independent numeric evaluation layers. Covers FR-004, FR-005, FR-006, AC-013, AC-014, AC-015, AC-016, AC-017, and AC-018.
- Tasks:
  - [ ] Implement no tolerance, absolute tolerance, relative tolerance, and absolute-or-relative tolerance.
  - [ ] Define and implement near-zero handling for relative tolerance according to the FDD decision made during implementation.
  - [ ] Implement legacy significant-figure precision separately from decimal-place precision.
  - [ ] Implement decimal-place precision rules for exactly, at least, and at most N decimal places.
  - [ ] Implement representation checks for unrestricted, integer-only, decimal, and scientific notation forms.
  - [ ] Ensure diagnostics distinguish value mismatch, tolerance failure, precision mismatch, and representation mismatch.
  - [ ] Add function-level comments for every non-trivial tolerance, precision, and representation function, explaining the rule's intent and whether it is new behavior or legacy compatibility behavior.
  - [ ] Add code-level comments explaining the ordering of value comparison, tolerance, precision, and representation checks, especially where behavior preserves legacy Torus semantics.
- Testing Tasks:
  - [ ] Add tolerance tests for values on, inside, and outside absolute, relative, and combined tolerance boundaries. Covers AC-014 and AC-016.
  - [ ] Add tests for legacy significant-figure precision and confirm it remains separate from decimal-place precision. Covers AC-013 and AC-015.
  - [ ] Add decimal precision tests for exactly, at least, and at most. Covers AC-015 and AC-016.
  - [ ] Add representation tests for integer, decimal, scientific, and any forms. Covers AC-017 and AC-018.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Numeric options compose with standard comparison operators without collapsing distinct failure reasons.
  - Legacy significant-figure behavior and new decimal-place behavior cannot be confused by type or tests.
- Gate:
  - Tolerance, precision, and representation tests pass on both targets before public wrapper work begins.
- Dependencies:
  - Phase 3 numeric parser and comparison behavior.
- Parallelizable Work:
  - Tolerance tests, precision tests, and representation tests can be developed independently once the numeric option types are stable.

## Phase 5: Public Evaluation API And Optional Torus Wrappers

- Goal: Finalize the public equality API and add only the thin Torus wrappers needed for test or prototype use. Covers FR-002, FR-008, AC-004, AC-005, AC-006, AC-021, AC-022, and AC-023.
- Tasks:
  - [ ] Finalize `evaluate_equality` and related public functions through `torus_math.gleam`.
  - [ ] Ensure equality results contain outcome and structured diagnostics only, with no feedback, score, response, activity lifecycle, or adaptive-page decisions.
  - [ ] Add `UnsupportedMode` behavior for future expression and unit-aware specs.
  - [ ] If needed, add `lib/oli/math/equality.ex` as a thin Elixir wrapper over the generated Gleam module.
  - [ ] If needed, add `assets/src/gleam/torusEquality.ts` as a thin TypeScript wrapper over generated JavaScript output.
  - [ ] Keep wrappers free of duplicated numeric semantics.
  - [ ] Add function-level comments for every non-trivial public Gleam API function, explaining caller intent and the boundary it protects.
  - [ ] Add code-level comments explaining public API stability, wrapper boundaries, and why evaluation output deliberately excludes feedback/scoring.
- Testing Tasks:
  - [ ] Add public API tests for evaluate success, not-equal diagnostics, invalid submitted answers, invalid config, and unsupported modes. Covers AC-004, AC-005, AC-006, and AC-020.
  - [ ] If Elixir wrapper is added, run targeted ExUnit wrapper tests.
  - [ ] If TypeScript wrapper is added, run targeted frontend type or build checks.
  - [ ] Run Gleam cross-target tests.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
  - Command(s): `mix test <targeted_math_equality_test_file>`
  - Command(s): `cd assets && yarn run check-types`
- Definition of Done:
  - Public equality API is usable from Gleam and, if implemented, from Torus wrapper boundaries.
  - No wrapper duplicates numeric behavior.
  - Equality result shape remains feedback-free and score-free.
- Gate:
  - Public API tests and any wrapper tests pass before parity corpus finalization.
- Dependencies:
  - Phase 4 numeric option behavior.
- Parallelizable Work:
  - Elixir and TypeScript wrapper work can proceed in parallel after public Gleam function names stabilize.

## Phase 6: Parity Corpus And Cross-Target Verification

- Goal: Prove the new equality evaluator matches standard/basic page numeric rule behavior and explicitly excludes adaptive-page behavior. Covers FR-003, FR-004, FR-009, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-024, AC-025, and AC-026.
- Tasks:
  - [ ] Build a parity corpus from `assets/src/data/activities/model/rules.ts` standard numeric operators: `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `btw`, and `nbtw`.
  - [ ] Include positive and negative cases for each operator.
  - [ ] Include edge cases for inclusive/exclusive ranges, inverse ranges, reversed bounds, scientific notation, parse failures, and legacy precision.
  - [ ] Add golden examples mapping each current standard numeric operator to the JSON equality config. Covers AC-009.
  - [ ] Add documentation or tests confirming adaptive numeric forms are intentionally absent from the corpus. Covers AC-025.
  - [ ] Add function-level comments for any Gleam parity helpers, explaining how they map standard/basic page rule behavior to the new equality config.
  - [ ] Add code-level comments in parity fixtures or helpers explaining which legacy behaviors are preserved and which adaptive paths are intentionally excluded.
- Testing Tasks:
  - [ ] Run the full Gleam equality test corpus on both targets.
  - [ ] Run any Elixir or TypeScript wrapper tests added in Phase 5.
  - [ ] Confirm no test depends on `AdaptivePartEvaluation` behavior.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
  - Command(s): `mix test <targeted_math_equality_test_file>`
  - Command(s): `cd assets && yarn run check-types`
- Definition of Done:
  - Parity corpus covers all standard numeric operators and required edge cases.
  - Adaptive page behavior is documented as out of scope and excluded from fixtures.
  - Cross-target equality behavior is deterministic for supported numeric configs.
- Gate:
  - Full parity corpus passes on both Gleam targets before final review and documentation reconciliation.
- Dependencies:
  - Phase 5 public API and optional wrappers.
- Parallelizable Work:
  - Operator mapping examples and edge-case fixtures can be built in parallel once JSON shape is stable.

## Phase 7: Documentation Reconciliation, Review, And Release Readiness

- Goal: Close the work item with traceability, verification evidence, and clear follow-up boundaries.
- Tasks:
  - [ ] Reconcile `prd.md`, `fdd.md`, `requirements.yml`, and this plan if implementation decisions changed.
  - [ ] Confirm no adaptive page evaluation code was changed and no adaptive parity scope was added.
  - [ ] Confirm no production evaluator reducer, database migration, storage schema, feature flag, cache, background job, or production telemetry was added.
  - [ ] Confirm raw student answers and raw expected answers are not logged by core Gleam or wrappers.
  - [ ] Capture commands run and outcomes in the implementation summary or PR description.
  - [ ] Prepare follow-up notes for legacy rule-string translation, production evaluator integration, authoring UI, algebraic equivalence, and unit support.
  - [ ] Run code review with security and performance lenses; include Elixir and TypeScript lenses if wrapper files changed.
- Testing Tasks:
  - [ ] Run final Gleam cross-target tests.
  - [ ] Run final targeted wrapper tests if wrappers were added.
  - [ ] Run formatting checks for changed Elixir and TypeScript files where applicable.
  - [ ] Run harness plan and requirements validation.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
  - Command(s): `mix format <changed_elixir_files> --check-formatted`
  - Command(s): `cd assets && yarn run check-types`
  - Command(s): `python3 <skills_root>/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/math/contract --action verify_plan`
  - Command(s): `python3 <skills_root>/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/math/contract --action master_validate --stage plan_present`
  - Command(s): `python3 <skills_root>/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/math/contract --check plan`
- Definition of Done:
  - Verification commands and any known unrelated failures are documented.
  - Security, privacy, performance, and compatibility risks have been reviewed.
  - Follow-up work is separated from this contract/numeric milestone.
- Gate:
  - Work is ready for PR review only after cross-target tests, targeted wrapper checks, docs validation, and review-prep checks are complete.
- Dependencies:
  - Phase 6 parity corpus and verification.
- Parallelizable Work:
  - Documentation reconciliation and review-prep notes can happen while final command runs are executing.

## Parallelization Notes

- Phase 1 type/result modeling and public API placeholder work can be split if ownership of files is explicit.
- Phase 2 fixture writing and decoder rejection test authoring can proceed while encoders/decoders are implemented.
- Phase 3 standard operator tests and range tests can proceed in parallel after numeric comparison variants stabilize.
- Phase 4 tolerance, precision, and representation work can be split across separate test modules and helpers once numeric parsing is stable.
- Phase 5 Elixir and TypeScript wrappers can proceed in parallel after public Gleam function names stabilize.
- Phase 6 parity corpus examples can be drafted independently from wrapper verification.
- Do not parallelize edits to the same equality type or numeric evaluator modules without explicit ownership, because type changes and comparison semantics are tightly coupled.
- Comment coverage should be reviewed as part of every code-writing phase, especially for public Gleam functions and compatibility-sensitive helper functions.

## Phase Gate Summary

- Gate A: PRD, FDD, requirements, and plan traceability are valid.
- Gate B: Equality type model and public API skeleton compile on Erlang and JavaScript targets.
- Gate C: JSON encode/decode and fixture tests pass on both targets.
- Gate D: Standard numeric operators and range semantics pass on both targets with adaptive behavior excluded.
- Gate E: Tolerance, precision, and representation constraints pass on both targets.
- Gate F: Public equality API and any optional wrappers pass targeted tests without duplicating Gleam semantics.
- Gate G: Parity corpus covers all standard/basic page numeric operators and edge cases, with adaptive pages documented as out of scope.
- Gate H: Final review confirms security, privacy, performance, compatibility, and verification evidence before implementation is considered complete.
