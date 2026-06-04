# Math Evaluation Integration - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/math/integration/prd.md`
- FDD: `docs/exec-plans/current/epics/math/integration/fdd.md`

## Scope

Implement production integration of the Gleam-based Torus Math evaluator into standard Short Answer and Multi Input activity evaluation. The work preserves existing standard evaluator score/feedback semantics, adds `matchConfig`-backed `math_expression` responses, supports old `numeric` and `math` rule-backed content at runtime, and converts edited legacy numeric/math authoring content to the new model shape on save.

Guardrails:
- Do not replace the standard evaluator, adaptive evaluator, lifecycle persistence, rollup, targeted response, or feedback action behavior.
- Do not run a database-wide activity migration.
- Do not serialize `rule` on new `math_expression` responses.
- Do not rename existing `numeric` or `math` input type strings to `legacy_numeric` or `legacy_math`.
- Do not add new learner-facing or author-preview diagnostic surfaces in this work.
- Do not log raw learner answers, raw expected answers, sampled assignments, or raw parser diagnostics by default.
- No feature flag is planned by default; runtime compatibility and test gates are the rollout protection.

## Clarifications & Default Assumptions

- `math_expression` is the exact new input type string.
- `matchConfig` is the exact serialized response field name.
- Parsed Elixir response structs may keep `rule: ""` in memory when a serialized `rule` is absent and `matchConfig` is present.
- A response with `matchConfig` must never match through its in-memory empty rule.
- Legacy Math is a text-rule matcher over a submitted LaTeX string; MathLive changes the input surface, not the rule grammar.
- Browser-side authoring saves serialize the full activity model with `JSON.stringify`; server-side activity save stores decoded nested map data in revision `content`.
- Existing rule fallback remains the safety net for unsupported old numeric/math rule shapes.

## Phase 1: Gleam Match Config Contract

- Goal: Add the shared match-config contract and evaluator modes needed by server and browser callers before wiring production evaluation to it.
- Tasks:
  - [ ] Define the Gleam `matchConfig` envelope with `version`, `type`, and math payload variants for `numeric`, `latex_direct`, `algebraic_equivalence`, `algebraic_equivalence` with exact form, `unit_aware`, and `always`.
  - [ ] Add public `torus_math` functions for `decode_match_config`, `encode_match_config`, and `evaluate_match`.
  - [ ] Reuse existing algebraic, exact-form, units, and numeric equality primitives instead of duplicating math logic.
  - [ ] Add structured result categories for match, non-match, invalid config, and invalid submission without score or feedback.
  - [ ] Ensure direct LaTeX mode applies only direct string comparison semantics required for legacy compatibility.
  - [ ] Keep diagnostic details structured and internal; avoid exposing raw details through default result summaries.
- Testing Tasks:
  - [ ] Add Gleam tests for decoding and encoding valid/invalid configs.
  - [ ] Add Gleam tests for algebraic equivalence, exact-form simplified fraction, unit-aware comparison, direct LaTeX, numeric significant figures, invalid submission, and always-match.
  - [ ] Run both BEAM and JavaScript targets.
  - Command(s): `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`; `cd gleam && gleam format --check src test`
- Definition of Done:
  - `torus_math` exposes a stable production match API.
  - Match outcomes can be normalized by Elixir without inspecting debug strings.
  - Gleam tests cover AC-015, AC-016, AC-017, AC-018, AC-019, AC-021, and AC-036.
- Gate:
  - Both Gleam targets pass before Elixir matchers call the new API.
- Dependencies:
  - Existing parser, algebraic equivalence, exact-form, equality, and units work.
- Parallelizable Work:
  - Backend model parsing tests from Phase 2 can be written against representative maps while this API is implemented.

## Phase 2: Activity Model Parsing And Matcher Boundary

- Goal: Add the Elixir data model fields and matcher seam while preserving standard evaluator semantics.
- Tasks:
  - [ ] Add `:match_config` to `Oli.Activities.Model.Response`.
  - [ ] Update `Response.parse/1` to preserve `"matchConfig"`, accept missing `"rule"` only when `matchConfig` is present, and assign an empty in-memory rule in that case.
  - [ ] Add `:input_type` to `Oli.Activities.Model.Part` as a literal string field.
  - [ ] Update `Oli.Activities.Model.parse/1` to annotate Short Answer parts from top-level `"inputType"`.
  - [ ] Update `Oli.Activities.Model.parse/1` to annotate Multi Input parts from `"inputs"` by `partId`.
  - [ ] Add `Oli.Delivery.Evaluation.ResponseMatcher.match?/3` and route non-math responses to `Rule.parse_and_evaluate/2`.
  - [ ] Update `Oli.Delivery.Evaluation.Evaluator` so `consider_response` delegates only match decisions to `ResponseMatcher` while leaving reducer, score, `out_of`, feedback, trigger, and lifecycle behavior unchanged.
- Testing Tasks:
  - [ ] Add ExUnit coverage for response parsing with `matchConfig` and missing `rule`.
  - [ ] Add ExUnit coverage for legacy response parsing with required `rule`.
  - [ ] Add ExUnit coverage for Short Answer and Multi Input input type annotation.
  - [ ] Add evaluator regression tests for all-responses-evaluated highest-score selection, equal-score tie ordering, score normalization, targeted response behavior, and empty-rule avoidance when `matchConfig` exists.
  - Command(s): `mix test <targeted activity model and evaluator tests>`; `mix format <changed Elixir files>`
- Definition of Done:
  - Parsed activity models carry enough metadata for matcher dispatch.
  - The evaluator policy layer remains behaviorally unchanged except for delegated match decisions.
  - Tests cover AC-001, AC-002, AC-003, AC-005, AC-006, AC-008, AC-009, AC-010, AC-011, AC-013, AC-014, and AC-035.
- Gate:
  - Backend parsing and evaluator regression tests pass before legacy adapters or math match routing are introduced.
- Dependencies:
  - None beyond existing evaluator and activity model code.
- Parallelizable Work:
  - Phase 1 Gleam tests and Phase 5 TypeScript type definitions can proceed in parallel.

## Phase 3: Elixir Math Matcher And Legacy Runtime Adapters

- Goal: Route new `matchConfig` responses and old numeric/math rules through one server-side matcher boundary with safe fallback.
- Tasks:
  - [ ] Add `Oli.Math.Match` as the production Elixir wrapper over `torus_math` match config APIs.
  - [ ] Add `Oli.Delivery.Evaluation.MathExpressionMatcher` to decode/evaluate `matchConfig` maps and normalize match outcomes.
  - [ ] Update `ResponseMatcher` dispatch so responses with `match_config` route to `MathExpressionMatcher`.
  - [ ] Add `Oli.Delivery.Evaluation.LegacyNumericRuleAdapter` using `Rule.parse/1` trees, not ad hoc string parsing.
  - [ ] Support legacy numeric equal, not equal, greater than, greater-than-or-equal, less than, less-than-or-equal, between, not-between, and significant-figure precision.
  - [ ] Add `Oli.Delivery.Evaluation.LegacyMathRuleAdapter` for simple legacy `input equals {...}` and supported input-ref equality rules.
  - [ ] Preserve legacy Math escaping/unescaping and `Oli.Utils.normalize_whitespace/1` submitted-input behavior.
  - [ ] Fall back to `Rule.parse_and_evaluate/2` for unsupported legacy numeric/math rule shapes.
- Testing Tasks:
  - [ ] Add ExUnit matcher dispatch tests for `matchConfig`, legacy numeric, legacy math, and non-math rule responses.
  - [ ] Add legacy numeric parity tests comparing adapter-backed results against current `Rule.parse_and_evaluate/2`.
  - [ ] Add legacy Math parity tests for escaped braces, backslashes, whitespace normalization, and fallback cases.
  - [ ] Add invalid config and invalid submission tests that verify learner-facing output still comes from normal evaluator fallback behavior.
  - Command(s): `mix test <targeted response matcher and legacy adapter tests>`; `mix format <changed Elixir files>`; `mix compile`
- Definition of Done:
  - New math responses route through Gleam-backed matching.
  - Old numeric and math content remains gradable without migration.
  - Unsupported old rules fall back to the current rule evaluator.
  - Tests cover AC-012, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020, AC-021, AC-022, AC-023, AC-024, AC-025, AC-026, AC-027, AC-031, and AC-035.
- Gate:
  - Matchers and adapters must pass parity tests before broader evaluation, preview, or scenario coverage is added.
- Dependencies:
  - Phase 1 match API.
  - Phase 2 model fields and matcher boundary.
- Parallelizable Work:
  - Frontend serialization tests from Phase 5 can proceed after the config shape is stable.

## Phase 4: Server Full-Model Integration, Persistence Shape, And Preview/Test Eval

- Goal: Prove the whole server-side activity JSON path can preserve and evaluate `matchConfig`.
- Tasks:
  - [ ] Add full-model server tests using Short Answer activity JSON with `inputType: "math_expression"` and `matchConfig` responses.
  - [ ] Add full-model server tests using Multi Input activity JSON with part-level `math_expression` metadata and `matchConfig` responses.
  - [ ] Simulate or exercise the activity save update shape used by `assets/src/data/persistence/activity.ts`, storing revision `content` as a map and reparsing after reload.
  - [ ] Verify `evaluate_from_preview/2`, test evaluation endpoints/helpers, and delivery evaluation all use the same matcher path.
  - [ ] Confirm no new author preview diagnostic surface is added.
  - [ ] If telemetry is added, restrict fields to aggregate-safe categories from the FDD.
- Testing Tasks:
  - [ ] Add ExUnit full-model persistence/parse/evaluate tests.
  - [ ] Add preview/test-eval tests for full activity models containing `matchConfig`.
  - [ ] Add privacy assertions or log-review tests where practical to ensure raw math diagnostics are not rendered in learner feedback.
  - Command(s): `mix test <targeted lifecycle/evaluation/full-model tests>`; `mix format <changed Elixir files>`
- Definition of Done:
  - Whole activity models can round-trip through server revision content and evaluate through `matchConfig`.
  - Delivery, author preview, and test-eval use the same matcher path.
  - Learners see authored feedback, not raw diagnostics.
  - Tests cover AC-004, AC-007, AC-014, AC-032, AC-033, AC-034, AC-035, and part of AC-038.
- Gate:
  - Server full-model tests pass before frontend save/conversion work is treated as complete.
- Dependencies:
  - Phase 2 model parsing.
  - Phase 3 matchers and adapters.
- Parallelizable Work:
  - Frontend UI and helper implementation can proceed once the stored `matchConfig` shape is fixed.

## Phase 5: Frontend Math Expression Schema, Helpers, And Serialization

- Goal: Add browser-side model support for `math_expression` and `matchConfig` without changing old content at runtime.
- Tasks:
  - [ ] Extend Short Answer input type schema to include `math_expression`.
  - [ ] Extend Multi Input input type schema to include `math_expression`.
  - [ ] Add TypeScript `MatchConfig` types and constructors for math expression modes.
  - [ ] Add response helpers that create `matchConfig` responses without serialized `rule`.
  - [ ] Add explicit always-match `matchConfig` catch-all helper for new math expression responses.
  - [ ] Preserve legacy rule helpers for text/dropdown and for old numeric/math parsing.
  - [ ] Update default new math-capable authoring paths to create `math_expression` instead of new `numeric` or `math` rule-backed configs where this work exposes the new editor.
  - [ ] Avoid UI diagnostic additions beyond existing preview behavior.
- Testing Tasks:
  - [ ] Add Jest tests for Short Answer and Multi Input schema acceptance of `math_expression`.
  - [ ] Add Jest tests for response helpers proving new math expression responses omit `rule`.
  - [ ] Add full activity-model `JSON.stringify`/`JSON.parse` tests for Short Answer and Multi Input containing nested `matchConfig`.
  - Command(s): `cd assets && yarn test <targeted activity authoring/model tests>`; `cd assets && yarn lint`; `cd assets && yarn format`
- Definition of Done:
  - Browser model code can represent and serialize new math expression responses.
  - New math expression catch-alls no longer use regex rules.
  - Tests cover AC-004, AC-007, AC-028, and AC-037.
- Gate:
  - Frontend serialization tests must pass before edit-time legacy conversion is completed.
- Dependencies:
  - Stable stored `matchConfig` shape from Phase 1 and FDD.
- Parallelizable Work:
  - Server full-model tests from Phase 4 can proceed with hand-authored JSON while this phase is implemented.

## Phase 6: Frontend Edit-Time Legacy Conversion

- Goal: Convert edited legacy numeric and math authoring content to `math_expression` plus `matchConfig` on save while leaving unedited content rule-backed at runtime.
- Tasks:
  - [ ] Add frontend conversion helpers from legacy numeric rules to numeric `matchConfig`.
  - [ ] Add frontend conversion helpers from legacy Math equality rules to direct LaTeX `matchConfig`.
  - [ ] Update Short Answer authoring load/save flows so existing `numeric` and `math` inputs remain editable but save as `math_expression`.
  - [ ] Update Multi Input authoring load/save flows so existing numeric/math parts remain editable but save as `math_expression`.
  - [ ] Ensure converted responses omit `rule`.
  - [ ] Ensure unedited old content is not mutated by delivery or evaluation paths.
  - [ ] Preserve existing accessibility and keyboard behavior for authoring controls.
- Testing Tasks:
  - [ ] Add Jest tests for numeric conversion: equality, inequalities, range/not-range, and significant figures.
  - [ ] Add Jest tests for legacy Math conversion with escaped LaTeX.
  - [ ] Add Jest tests proving saved converted models use `inputType: "math_expression"`, contain `matchConfig`, and omit `rule`.
  - [ ] Add regression tests proving text/dropdown rules still serialize as rules.
  - Command(s): `cd assets && yarn test <targeted conversion and authoring tests>`; `cd assets && yarn lint`; `cd assets && yarn format`
- Definition of Done:
  - Edited old numeric/math activities save into the new model shape.
  - Old unedited content remains supported only through runtime compatibility.
  - Tests cover AC-029, AC-030, AC-031, and AC-037.
- Gate:
  - Conversion tests pass before end-to-end workflow tests are finalized.
- Dependencies:
  - Phase 5 frontend schema/helpers.
  - Phase 3 runtime adapters for parity expectations.
- Parallelizable Work:
  - Scenario infrastructure assessment can proceed in parallel; scenario implementation depends on server and frontend behavior being available.

## Phase 7: Workflow Coverage, Hardening, And Release Gates

- Goal: Validate authoring, publishing, delivery, privacy, and compatibility behavior end to end.
- Tasks:
  - [ ] Add integration or scenario coverage for authoring, publishing, and delivery of a new `math_expression` activity with correct, partial-credit, and always-match responses.
  - [ ] Add workflow coverage for exact-form matching, including simplified fraction.
  - [ ] Add workflow coverage for unit-aware matching.
  - [ ] Add workflow coverage proving old unedited numeric and math content still evaluates correctly.
  - [ ] Add manual QA notes for authoring new math expression questions, editing old numeric/math questions, previewing, publishing, and learner delivery.
  - [ ] Review logs/telemetry changes, if any, for aggregate-safe fields only.
  - [ ] Run security and performance review before release, plus Elixir, Gleam, TypeScript/UI, and requirements review as applicable.
- Testing Tasks:
  - [ ] Validate any new scenario files with `Oli.Scenarios.validate_file/1`.
  - [ ] Run targeted scenario or integration runner.
  - [ ] Run targeted backend, Gleam, and frontend tests from earlier phases.
  - [ ] Run formatting checks for touched Elixir, Gleam, and TypeScript files.
  - Command(s): `mix test <targeted scenario/integration tests>`; `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`; `cd assets && yarn test <targeted tests>`; `mix format <changed Elixir files>`; `cd gleam && gleam format --check src test`; `cd assets && yarn lint`
- Definition of Done:
  - New and legacy workflows are covered across authoring, publish, delivery, and feedback.
  - No raw math diagnostics are exposed to learners or logged by default.
  - Review gates are ready with security and performance included.
  - Tests cover AC-032, AC-033, AC-034, AC-036, AC-037, and AC-038.
- Gate:
  - All targeted phase gates pass and no critical security, privacy, performance, or requirements review findings remain unresolved.
- Dependencies:
  - Phases 1 through 6.
- Parallelizable Work:
  - Manual QA checklist drafting can happen while final scenario coverage is implemented.

## Parallelization Notes

- Phase 1 and the Phase 2 parsing/evaluator regression tests can start in parallel because Phase 2 can initially use stubbed or hand-authored `matchConfig` maps.
- Phase 5 TypeScript type/helper work can start once the match config storage shape is stable, even before all server match modes are implemented.
- Phase 4 full-model server tests and Phase 5 browser serialization tests should both assert the same storage contract from different sides.
- Phase 6 conversion work should wait for Phase 5 helpers, but its test cases can be drafted from existing `rules.ts` examples while Phase 5 is in progress.
- Phase 7 workflow coverage depends on the integration path being functional, but scenario capability assessment can happen earlier.

## Phase Gate Summary

- Gate 1: Gleam match API passes Erlang and JavaScript tests.
- Gate 2: Elixir activity model parsing and evaluator reducer regression tests pass.
- Gate 3: Response matcher and legacy adapter parity tests pass.
- Gate 4: Server full-model persistence, parse, preview, and evaluation tests pass.
- Gate 5: Frontend `math_expression`, `matchConfig`, and full-model serialization tests pass.
- Gate 6: Frontend edit-time numeric/math conversion tests pass.
- Gate 7: Workflow/scenario coverage, targeted suites, formatting, and review gates pass.

## Requirement Trace Notes

- Phase 1: AC-015, AC-016, AC-017, AC-018, AC-019, AC-021, AC-036.
- Phase 2: AC-001, AC-002, AC-003, AC-005, AC-006, AC-008, AC-009, AC-010, AC-011, AC-013, AC-014, AC-035.
- Phase 3: AC-012, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020, AC-021, AC-022, AC-023, AC-024, AC-025, AC-026, AC-027, AC-031, AC-035.
- Phase 4: AC-004, AC-007, AC-014, AC-032, AC-033, AC-034, AC-035, AC-038.
- Phase 5: AC-004, AC-007, AC-028, AC-037.
- Phase 6: AC-029, AC-030, AC-031, AC-037.
- Phase 7: AC-032, AC-033, AC-034, AC-036, AC-037, AC-038.
