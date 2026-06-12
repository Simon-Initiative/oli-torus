# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/math/integration`
Phase: `2 - Activity Model Parsing And Matcher Boundary`

## Scope from plan.md
- Add `matchConfig` preservation to parsed responses while keeping legacy `rule` parsing intact.
- Add part-level input type metadata for Short Answer and Multi Input activity models.
- Introduce an evaluator-facing response matcher boundary.
- Update standard evaluation to delegate only the match decision while preserving score, feedback, `out_of`, targeted response, trigger, and fallback behavior.

## Implementation Blocks
- [x] Core behavior changes
  - Added `Oli.Delivery.Evaluation.ResponseMatcher.match?/3`.
  - Updated `Oli.Delivery.Evaluation.Evaluator` to call `ResponseMatcher` from `consider_response/3`.
  - Non-`matchConfig` responses continue through `Rule.parse_and_evaluate/2`.
  - `matchConfig` responses are intercepted and currently return `{:error, :match_config_not_supported}` so stale or empty rules are not evaluated before Phase 3 math matcher wiring.
- [x] Data or interface changes
  - Added `:match_config` to `Oli.Activities.Model.Response`.
  - `Response.parse/1` now accepts missing `"rule"` only when `"matchConfig"` is present and assigns `rule: ""` in memory.
  - Added `:input_type` to `Oli.Activities.Model.Part`.
  - `Oli.Activities.Model.parse/1` annotates Short Answer parts from top-level `"inputType"` and Multi Input parts from matching `"inputs"` entries by `partId`.
- [x] Access-control or safety checks
  - No authorization surface changed.
  - No raw learner answer logging, telemetry, or diagnostic display was added.
  - Responses with `matchConfig` do not fall through to stale legacy rules.
- [x] Observability or operational updates when needed
  - No telemetry or logging was added in Phase 2.

## Test Blocks
- [x] Tests added or updated
  - Added response parser coverage for `matchConfig` with missing `rule`, legacy rule parsing, and missing-rule rejection.
  - Added activity model parser coverage for Short Answer and Multi Input input type annotation.
  - Added evaluator regression coverage for highest-scoring match selection, equal-score tie ordering, score scaling, targeted behavior, and stale-rule avoidance when `matchConfig` exists.
  - Added direct `ResponseMatcher` coverage for ordinary rule routing and `matchConfig` interception.
- [x] Required verification commands run
  - `mix test test/oli/activities/parse_test.exs test/oli/delivery/evaluation/evaluator_test.exs test/oli/delivery/evaluation/response_matcher_test.exs`
  - `mix test test/oli/delivery/evaluation test/oli/activities/parse_test.exs`
  - `mix compile --warnings-as-errors`
  - `mix format lib/oli/activities/model.ex lib/oli/activities/model/response.ex lib/oli/activities/model/part.ex lib/oli/delivery/evaluation/evaluator.ex lib/oli/delivery/evaluation/response_matcher.ex test/oli/activities/parse_test.exs test/oli/delivery/evaluation/evaluator_test.exs test/oli/delivery/evaluation/response_matcher_test.exs`
- [x] Results captured
  - Targeted parser/evaluator/matcher tests: 16 tests, 0 failures.
  - Broader delivery evaluation plus parser tests: 46 tests, 0 failures.
  - Compile with warnings as errors passed.
  - Formatting completed.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - No PRD/FDD/plan divergence found. The temporary `:match_config_not_supported` result is the Phase 2 seam; Phase 3 owns actual math matcher dispatch.
- [x] Open questions added to docs when needed
  - No new open questions were introduced.

## Review Loop
- Round 1 findings:
  - No actionable Phase 2 defects found in the security, performance, or Elixir review pass.
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
