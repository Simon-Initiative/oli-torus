# Exact Form And Representation Constraints - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/math/exact-form/prd.md`
- FDD: `docs/exec-plans/current/epics/math/exact-form/fdd.md`
- Requirements: `docs/exec-plans/current/epics/math/exact-form/requirements.yml`
- Supporting informal notes: `docs/exec-plans/current/epics/math/exact-form/informal.md`

## Scope
Deliver exact-form constraints as a shared Gleam Math Expression layer plus developer-only prototype access.

In scope:
- Add exact-form config, observed-form summaries, form failures, standalone form results, and form-aware algebraic result types.
- Implement AST/source-metadata whole-answer classification for integer, decimal, fraction, and other forms.
- Enforce integer-only, fraction-only, simplified-fraction, decimal-form, and decimal-place precision constraints.
- Add form-aware algebraic checking that runs form checks only after semantic equivalence succeeds.
- Expose stable public APIs and debug formatters through `gleam/src/torus_math.gleam`.
- Add a thin `Oli.Math.ExactForm` bridge for developer prototype use.
- Extend `lib/oli_web/live/dev/math_prototype_live.ex` with exact-form controls and diagnostics.
- Preserve existing Number-input scalar representation and precision behavior.
- Add cross-target Gleam tests and targeted Elixir/LiveView tests.

Out of scope:
- Production grading integration for Short Answer, Multi-Input, Number, legacy Math, adaptive activities, or response rules.
- Production authoring UI, learner UI, activity JSON persistence, database migrations, scoring, feedback-rule matching, or telemetry.
- Unit-aware exact form, LaTeX form preservation, factored/expanded/collected/radical/polynomial/rational-expression form checks, or arbitrary precision arithmetic.

## Clarifications & Default Assumptions
- Simplified fractions require a positive denominator. `-4/5` is canonical; `4/-5` is non-canonical.
- Zero fractions simplify only as `0/1`; `0/5` is unsimplified.
- Unary plus is accepted for the same literal-form shapes where unary minus is accepted.
- Scientific notation is not decimal form for Math Expression exact-form constraints.
- Fraction form means whole-answer division of integer literals, not variable rational expressions such as `1/x`.
- Large integer literals outside `-9007199254740991..9007199254740991` fail exact-form arithmetic details with `UnsafeIntegerLiteral`.
- The Math Prototype LiveView update is developer-only diagnostics UI. It must not persist inputs/results or become production authoring or learner UI.
- Add useful Gleam comments at the function level for all exported form APIs and public formatter functions. Also add short comments around policy-heavy private helpers such as sign peeling, safe integer parsing, fraction canonicalization, decimal precision matching, and semantic-before-form gating.

## Phase 1: Exact-Form Type Contracts
- Goal: Define the typed exact-form contract without implementing classification behavior.
- Tasks:
  - [ ] Add `gleam/src/math/equality/form_types.gleam`.
  - [ ] Define `ExactFormConfig`, `DecimalPrecisionConstraint`, observed form summary/kind types, form failures, form config errors, standalone form result, and form-aware algebraic result.
  - [ ] Reuse `math/equality/types.DecimalPlaceRule` for decimal precision rules unless doing so creates awkward imports; otherwise mirror the variants and provide conversion helpers.
  - [ ] Add `default_exact_form_config`.
  - [ ] Add function-level Gleam comments for all exported helpers and type-level comments for exported variants that later authoring UI or feedback mapping may consume.
  - [ ] Keep result summaries production-safe by not requiring raw submitted text.
- Testing Tasks:
  - [ ] Add `gleam/test/math_equality_form_types_test.gleam`.
  - [ ] Assert constructors can represent no constraint, integer, fraction, simplified fraction, decimal with any places, and decimal with exactly/at-least/at-most places for `AC-001`.
  - [ ] Assert result and failure constructors can represent satisfied form, unsatisfied form, parse failure, invalid config, wrong form, unsimplified fraction, decimal precision mismatch, non-canonical sign, and unsafe integer detail for `AC-002`.
  - Command(s): `cd gleam && gleam format --check src test`; `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Exact-form contract compiles on both Gleam targets.
  - Exported types/functions include function-level or type-level comments where appropriate.
  - `AC-001` and `AC-002` are representable by typed values.
- Gate:
  - Gate A passes when exact-form contracts and type tests pass on both Gleam targets.
- Dependencies:
  - Existing parser/equality type modules.
- Parallelizable Work:
  - Debug string expectation drafting can start once constructor names settle.

## Phase 2: Whole-Answer Classifier And Form Rules
- Goal: Implement AST/source-metadata classification and exact-form rule checks for standalone candidates.
- Tasks:
  - [ ] Add `gleam/src/math/equality/form.gleam`.
  - [ ] Implement `check_exact_form(candidate, config)`.
  - [ ] Validate decimal precision counts before applying submitted-form rules.
  - [ ] Parse raw candidates through `math/parser.parse`.
  - [ ] Implement whole-answer classification for integer, decimal, fraction, and other shapes.
  - [ ] Implement sign peeling for unary `+` and `-` without accepting non-literal equivalent expressions.
  - [ ] Implement safe integer parsing bounded to `-9007199254740991..9007199254740991`.
  - [ ] Implement scalar integer-literal fraction extraction with supported sign placement and denominator-zero rejection.
  - [ ] Implement simplified-fraction checks with GCD, positive-denominator policy, and zero-denominator policy.
  - [ ] Implement decimal precision matching from `NumberLiteral.decimal_places`.
  - [ ] Add function-level Gleam comments for exported functions and targeted comments on sign peeling, unsafe integer rejection, positive-denominator policy, zero fraction policy, and why the checker inspects source AST instead of floats.
- Testing Tasks:
  - [ ] Add `gleam/test/math_equality_form_test.gleam`.
  - [ ] Cover integer classification and integer-only rules for `AC-003` and `AC-006`.
  - [ ] Cover fraction classification and fraction-only rules for `AC-004` and `AC-007`.
  - [ ] Cover decimal classification for `AC-005`.
  - [ ] Cover simplified fraction failures for common factors, `0/5`, negative denominators, denominator zero, and unsafe integer components for `AC-008`.
  - [ ] Cover decimal precision exactly, at least, and at most rules for `AC-009`.
  - [ ] Cover invalid form config for negative decimal-place counts.
  - Command(s): `cd gleam && gleam format --check src test`; `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Standalone form checks return structured results for valid forms, wrong forms, invalid config, parse failures, non-canonical fraction signs, unsimplified fractions, decimal precision mismatches, and unsafe integers.
  - Classifier uses parsed AST and numeric literal metadata, not evaluated floats.
  - Function-level Gleam comments are present on exported APIs and policy-heavy helpers.
- Gate:
  - Gate B passes when `AC-003` through `AC-009` pass on both Gleam targets.
- Dependencies:
  - Phase 1 exact-form types.
- Parallelizable Work:
  - Form-aware algebraic result tests can be sketched in parallel but should not execute until Phase 3 behavior exists.

## Phase 3: Form-Aware Algebraic API And Public Boundary
- Goal: Layer exact-form checks onto semantic equivalence and expose the public Gleam boundary.
- Tasks:
  - [ ] Implement `check_algebraic_equivalence_with_form` in `gleam/src/math/equality/form.gleam`.
  - [ ] Gate form checks on `algebraic_types.Equivalent(_)` only.
  - [ ] Preserve all non-equivalent, parse, validation, domain, runtime, invalid config, and insufficient sample outcomes as `SemanticsFailed`.
  - [ ] Treat unexpected standalone form parse failure after semantic success as a structured defensive form failure.
  - [ ] Update `gleam/src/torus_math.gleam` with `default_exact_form_config`, `check_exact_form`, `check_algebraic_equivalence_with_form`, and placeholder formatter exports if Phase 4 has not landed yet.
  - [ ] Add function-level Gleam comments to all new public `torus_math` exports and form-aware functions explaining semantic-before-form ordering and non-production grading scope.
- Testing Tasks:
  - [ ] Add `gleam/test/math_equality_form_algebraic_test.gleam`.
  - [ ] Cover expected `4/5`, candidate `8/10`, required simplified fraction as semantic pass plus form failure for `AC-010`.
  - [ ] Cover expected `4/5`, candidate `8/11`, required simplified fraction as semantic failure, not primary wrong-form failure, for `AC-011`.
  - [ ] Cover malformed candidates, unexpected variables, disallowed functions, invalid domains/configs, runtime failures, and insufficient samples preserving semantic outcomes for `AC-012`.
  - [ ] Cover public `torus_math` APIs for `AC-013`.
  - Command(s): `cd gleam && gleam format --check src test`; `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Form-aware algebraic checks preserve existing algebraic outcomes unless semantics pass.
  - Public `torus_math` APIs are stable and commented.
  - `AC-010`, `AC-011`, `AC-012`, and public API parts of `AC-013` pass.
- Gate:
  - Gate C passes when semantic-before-form ordering is proven on both Gleam targets.
- Dependencies:
  - Phase 2 standalone form checks and existing algebraic equivalence.
- Parallelizable Work:
  - Elixir bridge API shape can be drafted in parallel after public function names settle.

## Phase 4: Stable Debug Formatting And Comment Audit
- Goal: Add target-stable exact-form diagnostics and audit Gleam comments.
- Tasks:
  - [ ] Add `gleam/src/math/equality/form_format.gleam`.
  - [ ] Implement stable formatting for form config, observed form summary, form failures, standalone form results, and form-aware algebraic results.
  - [ ] Avoid target-specific inspect output in formatter paths.
  - [ ] Document formatter output as developer/test diagnostics, not learner-facing feedback or production telemetry.
  - [ ] Update `gleam/src/torus_math.gleam` formatter exports if not already complete.
  - [ ] Audit all new Gleam modules for function-level comments on exported functions and useful comments on private policy-heavy helpers. Add comments where missing before this gate closes.
- Testing Tasks:
  - [ ] Add `gleam/test/math_equality_form_format_test.gleam`.
  - [ ] Cover stable strings for satisfied form, wrong form, unsimplified fraction, decimal precision mismatch, invalid config, parse failure, semantic failure, semantic pass plus form pass, and semantic pass plus form fail for `AC-014`.
  - [ ] Add repeated-run deterministic debug assertions for `AC-019`.
  - [ ] Re-run public API tests for `AC-013`.
  - Command(s): `cd gleam && gleam format --check src test`; `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Debug formatting is target-stable and covered by tests.
  - Formatter comments clearly state non-learner-facing and non-production-telemetry usage.
  - Function-level Gleam comment audit is complete.
- Gate:
  - Gate D passes when `AC-013`, `AC-014`, and formatter portions of `AC-019` pass on both Gleam targets.
- Dependencies:
  - Phase 3 public result shapes.
- Parallelizable Work:
  - Elixir bridge tests can be prepared against final public function names.

## Phase 5: Elixir Bridge For Prototype Use
- Goal: Add a thin server-side bridge from the Math Prototype LiveView to the public Gleam exact-form APIs.
- Tasks:
  - [ ] Add `lib/oli/math/exact_form.ex`.
  - [ ] Implement `default_config/0`, `check/2`, `check_algebraic/4`, `result_debug/1`, `form_aware_result_debug/1`, and `config_from_form/1`.
  - [ ] Pattern-match known form selector strings: `none`, `integer`, `fraction`, `simplified_fraction`, and `decimal`.
  - [ ] Pattern-match known precision selector strings: `any`, `exactly`, `at_least`, and `at_most`.
  - [ ] Parse decimal precision counts as non-negative integers and return structured field errors for invalid input.
  - [ ] Avoid dynamic atoms from user input.
  - [ ] Keep the bridge thin; do not reimplement form classification or algebraic semantics in Elixir.
- Testing Tasks:
  - [ ] Add `test/oli/math/exact_form_test.exs`.
  - [ ] Cover bridge calls to public Gleam default config, standalone check, form-aware algebraic check, and debug formatters.
  - [ ] Cover config conversion for each form selector and each decimal precision selector.
  - [ ] Cover unknown selector, negative precision, and non-integer precision errors without crashes or dynamic atoms.
  - [ ] Cover form-aware `4/5` vs `8/10` behavior through the bridge for `AC-010` and public bridge coverage for `AC-013`.
  - Command(s): `mix format --check-formatted lib/oli/math/exact_form.ex test/oli/math/exact_form_test.exs`; `mix test test/oli/math/exact_form_test.exs`
- Definition of Done:
  - Elixir bridge is a thin adapter to public Gleam exact-form APIs.
  - Invalid prototype form config returns structured errors.
  - No dynamic atoms are created from user input.
- Gate:
  - Gate E passes when bridge tests pass and security/privacy checks for raw input handling are satisfied.
- Dependencies:
  - Phase 4 public Gleam APIs and debug formatter names.
- Parallelizable Work:
  - LiveView markup can be sketched after bridge params are defined, but event handling should wait for bridge behavior.

## Phase 6: Math Prototype LiveView Integration
- Goal: Expose exact-form controls and diagnostics in the existing developer-only Math Prototype LiveView.
- Tasks:
  - [ ] Update `lib/oli_web/live/dev/math_prototype_live.ex`.
  - [ ] Extend default algebraic form state with `form_constraint`, `decimal_precision_rule`, and `decimal_precision_count`.
  - [ ] Extend `update_algebraic_form` and form param normalization to preserve exact-form fields.
  - [ ] Update `check_algebraic_equivalence` to build both algebraic config and exact-form config.
  - [ ] When exact-form constraint is `none`, preserve existing algebraic diagnostics or render equivalent no-form-aware diagnostics without regressing existing output.
  - [ ] When exact-form constraint is concrete, call `Oli.Math.ExactForm.check_algebraic/4`.
  - [ ] Render exact-form controls in the existing Algebraic Equivalence panel.
  - [ ] Render semantic outcome, form outcome, observed form, form failures, exact-form debug text, and existing algebraic diagnostics.
  - [ ] Render form config errors in the existing error panel style.
  - [ ] Keep all exact-form state transient in LiveView assigns and do not persist inputs/results.
  - [ ] Keep the panel developer-only and avoid production authoring or learner UI integration.
- Testing Tasks:
  - [ ] Update `test/oli_web/live/dev/math_prototype_live_test.exs`.
  - [ ] Assert exact-form controls render in the Algebraic Equivalence panel.
  - [ ] Assert simplified fraction check for expected `4/5` and candidate `8/10` displays semantic pass plus form failure for `AC-010`.
  - [ ] Assert expected `4/5` and candidate `8/11` displays semantic failure as primary for `AC-011`.
  - [ ] Assert malformed candidates or invalid form config display structured errors without crashes for `AC-012`.
  - [ ] Assert decimal precision controls render and validate exactly/at-least/at-most counts for `AC-009`.
  - [ ] Assert no production grading or learner/authoring UI files are touched for `AC-016`.
  - Command(s): `mix format --check-formatted lib/oli_web/live/dev/math_prototype_live.ex test/oli_web/live/dev/math_prototype_live_test.exs`; `mix test test/oli_web/live/dev/math_prototype_live_test.exs`
- Definition of Done:
  - Developer prototype can exercise exact-form constraints through UI controls.
  - Existing parser and algebraic prototype behavior remains available.
  - LiveView tests cover controls, success, form failure, semantic failure precedence, and config errors.
- Gate:
  - Gate F passes when LiveView tests pass and inspection confirms no production UI or grading integration.
- Dependencies:
  - Phase 5 Elixir bridge.
- Parallelizable Work:
  - Final docs/review preparation can proceed while LiveView tests are being completed.

## Phase 7: Final Verification, Compatibility, And Review
- Goal: Run complete targeted validation and document residual risks before implementation is considered complete.
- Tasks:
  - [ ] Run the full required Gleam format and both target test suites.
  - [ ] Run targeted Elixir bridge and LiveView tests.
  - [ ] Run targeted numeric equality tests if any shared helper extraction touched numeric representation or precision behavior.
  - [ ] Inspect changed files for production grading, activity JSON, persistence, authoring UI, learner UI, response-rule, scoring, telemetry, or feedback-rule drift.
  - [ ] Inspect for raw submitted expression, expected answer, numeric fragment, or sampled assignment logging in production paths.
  - [ ] Verify no dynamic atoms are created from prototype form input.
  - [ ] Verify new exported Gleam functions have function-level comments and policy-heavy helpers have short clarifying comments.
  - [ ] Run local review using `.review/security.md`, `.review/performance.md`, `.review/requirements.md`, `.review/gleam.md`, `.review/elixir.md`, and `.review/ui.md`.
- Testing Tasks:
  - [ ] Run `cd gleam && gleam format --check src test`.
  - [ ] Run `cd gleam && gleam test --target erlang`.
  - [ ] Run `cd gleam && gleam test --target javascript`.
  - [ ] Run `mix format --check-formatted lib/oli/math/exact_form.ex lib/oli_web/live/dev/math_prototype_live.ex test/oli/math/exact_form_test.exs test/oli_web/live/dev/math_prototype_live_test.exs`.
  - [ ] Run `mix test test/oli/math/exact_form_test.exs test/oli_web/live/dev/math_prototype_live_test.exs`.
  - [ ] Run existing numeric equality tests if touched: `cd gleam && gleam test --target erlang` and `cd gleam && gleam test --target javascript` already include them; optionally run focused numeric tests during development.
- Definition of Done:
  - `AC-001` through `AC-019` are covered by tests or inspection.
  - Existing Number-input scalar representation and precision behavior remains compatible for `AC-015`.
  - Production behavior boundaries remain unchanged for `AC-016`.
  - No production logs/telemetry emit raw learner math details for `AC-017`.
  - Cross-target suites pass for `AC-018` and `AC-019`.
- Gate:
  - Gate G passes when all required commands pass, review findings are resolved or documented, and acceptance-criteria coverage is complete.
- Dependencies:
  - Phases 1 through 6.
- Parallelizable Work:
  - Review and documentation inspection can run in parallel with final test execution once code is stable.

## Parallelization Notes
- Phase 1 blocks all implementation because it defines shared result/config types.
- Phase 2 and Phase 4 test fixture drafting can overlap once type names settle, but executable formatter work should wait for result shapes.
- Phase 5 bridge skeleton can begin after Phase 3 public function names settle; final bridge tests depend on Phase 4 debug formatter names.
- Phase 6 markup planning can overlap with Phase 5, but event handling depends on `Oli.Math.ExactForm.config_from_form/1`.
- Final review work can start during late Phase 6, but Gate G should wait for all code and tests.

## Phase Gate Summary
- Gate A: Exact-form contracts compile and type tests cover `AC-001` and `AC-002`.
- Gate B: Standalone AST/source-metadata form checks cover `AC-003` through `AC-009`.
- Gate C: Form-aware algebraic checks prove semantic-before-form ordering for `AC-010` through `AC-012` and public API coverage for `AC-013`.
- Gate D: Stable debug formatting and Gleam function-level comment audit cover `AC-014`, `AC-019`, and remaining `AC-013` formatter exports.
- Gate E: Elixir bridge converts prototype form params safely and calls public Gleam APIs.
- Gate F: Math Prototype LiveView exposes exact-form controls and diagnostics without production UI or grading integration.
- Gate G: Full validation, compatibility, privacy, and review pass for `AC-001` through `AC-019`.
