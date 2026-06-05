# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/math/integration`
Phase: `3 - Elixir Math Matcher And Legacy Runtime Adapters`

## Scope from plan.md
- Route new `matchConfig` responses through the Gleam-backed math matching API.
- Add the server-side math expression matcher boundary used by standard evaluation.
- Translate supported old `numeric` and `math` rule-backed responses at runtime while preserving fallback to the existing rule evaluator.
- Add parity and dispatch tests for new math expression responses and legacy compatibility paths.

## Implementation Blocks
- [x] Core behavior changes
  - Added `Oli.Math.Match` as the production Elixir wrapper around `torus_math` match config decode, encode, and evaluation APIs.
  - Added `Oli.Delivery.Evaluation.MathExpressionMatcher` to evaluate response `matchConfig` maps against submitted learner input and normalize match, non-match, invalid-submission, and invalid-config outcomes.
  - Updated `Oli.Delivery.Evaluation.ResponseMatcher` so responses with `match_config` route to the math expression matcher before any legacy rule fallback.
  - Added `Oli.Delivery.Evaluation.LegacyNumericRuleAdapter` using parsed `Rule.parse/1` trees for supported numeric equality, inequality, range, not-range, input-ref, and significant-figure rules.
  - Added `Oli.Delivery.Evaluation.LegacyMathRuleAdapter` for simple legacy LaTeX equality rules, including input-ref equality.
  - Added `Oli.Delivery.Evaluation.LegacyInput` to centralize submitted value extraction and existing whitespace normalization behavior.
  - Preserved `Rule.parse_and_evaluate/2` fallback for unsupported old numeric/math rule shapes.
- [x] Data or interface changes
  - `ResponseMatcher.match?/3` now accepts both new `matchConfig` responses and old rule-backed responses through the same evaluator-facing API.
  - `Oli.Math.Match.evaluate_json/2` accepts stored config maps or JSON strings and returns structured match results without score, feedback, or learner-facing diagnostics.
- [x] Access-control or safety checks
  - No authorization surface changed.
  - Invalid math config is treated as a matcher error and therefore as a non-match by the existing evaluator selection flow.
  - Invalid learner submissions produce non-match outcomes without exposing raw parser diagnostics as feedback.
  - No raw learner answers, raw expected answers, sampled assignments, or parser traces were logged.
- [x] Observability or operational updates when needed
  - No telemetry or logging was added in Phase 3.

## Test Blocks
- [x] Tests added or updated
  - Added `test/oli/delivery/evaluation/legacy_rule_adapter_test.exs` for numeric adapter parity, range and significant-figure behavior, input-ref behavior, unsupported fallback, legacy Math direct equality, escaping, backslashes, whitespace normalization, and fallback cases.
  - Updated `test/oli/delivery/evaluation/response_matcher_test.exs` for `matchConfig` dispatch, algebraic equivalence, exact-form simplified fractions, unit-aware matching, invalid config handling, and ordinary rule dispatch.
  - Updated `test/oli/delivery/evaluation/evaluator_test.exs` to verify new math expression invalid-submission behavior and stale-rule avoidance with invalid `matchConfig`.
- [x] Required verification commands run
  - `mix format lib/oli/math/match.ex lib/oli/delivery/evaluation/math_expression_matcher.ex lib/oli/delivery/evaluation/legacy_input.ex lib/oli/delivery/evaluation/legacy_numeric_rule_adapter.ex lib/oli/delivery/evaluation/legacy_math_rule_adapter.ex lib/oli/delivery/evaluation/response_matcher.ex test/oli/delivery/evaluation/response_matcher_test.exs test/oli/delivery/evaluation/legacy_rule_adapter_test.exs test/oli/delivery/evaluation/evaluator_test.exs`
  - `mix test test/oli/delivery/evaluation/response_matcher_test.exs test/oli/delivery/evaluation/legacy_rule_adapter_test.exs test/oli/delivery/evaluation/evaluator_test.exs`
  - `mix test test/oli/delivery/evaluation test/oli/activities/parse_test.exs`
  - `mix test test/oli/delivery/evaluation/response_matcher_test.exs test/oli/delivery/evaluation/legacy_rule_adapter_test.exs test/oli/delivery/evaluation/evaluator_test.exs --warnings-as-errors`
  - `mix compile --warnings-as-errors`
- [x] Results captured
  - Targeted response matcher, legacy adapter, and evaluator tests: 21 tests, 0 failures.
  - Broader delivery evaluation plus activity parser tests: 57 tests, 0 failures.
  - Targeted warning-as-errors test run: 21 tests, 0 failures.
  - Compile with warnings as errors passed.
  - Formatting completed.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - No PRD/FDD/plan divergence found.
  - Implementation deliberately leaves compound numeric rules and negated precision rules on `Rule.parse_and_evaluate/2` fallback because translating those into a single `matchConfig` would change existing truth tables.
- [x] Open questions added to docs when needed
  - No new open questions were introduced.

## Review Loop
- Round 1 findings:
  - No actionable Phase 3 defects found in the security, performance, or Elixir review pass.
- Round 1 fixes:
  - None required.
- Round 2 findings (optional):
  - Not run.
- Round 2 fixes (optional):
  - None.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
