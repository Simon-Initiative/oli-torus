# Math Evaluation Integration Approach

## Purpose

This document describes how to integrate the shared Gleam-based Torus Math evaluation engine into the existing activity evaluation system without replacing Torus' response/feedback/scoring model.

The target architecture is:

- Existing activity parts continue to own their response list and current response selection semantics.
- Matching responses are reduced exactly as they are today: highest score wins, and response order only matters when matching scores tie.
- Each response continues to own score, feedback, correctness metadata, and optional navigation/show-page behavior.
- Math evaluation becomes one possible response matching mechanism, not a replacement for responses.
- New authored `math_expression` responses store a typed math `matchConfig` on the response and do not serialize a legacy `rule`.
- Existing authored Number and Math responses remain valid and are translated in memory at evaluation time.
- Existing activities are not migrated in the database as part of this integration.

## Current Evaluation Path

The standard server-side path is:

- `lib/oli/delivery/attempts/activity_lifecycle/evaluate.ex`
  - `evaluate_activity/4` loads the attempt, selects the activity model, parses it with `Oli.Activities.Model.parse/1`, and routes non-adaptive activities to `evaluate_from_input/5`.
  - `evaluate_from_preview/2` and `perform_test_eval/3` use the same parsed model and evaluator path for local/test evaluation.
- `lib/oli/delivery/attempts/activity_lifecycle/utils.ex`
  - `do_evaluate_submissions/4` builds an `Oli.Delivery.Evaluation.EvaluationContext` per submitted part and calls `Oli.Delivery.Evaluation.Standard.perform/4`.
- `lib/oli/delivery/evaluation/standard.ex`
  - Delegates to `Oli.Delivery.Evaluation.Evaluator.evaluate/3`.
- `lib/oli/delivery/evaluation/evaluator.ex`
  - Iterates `part.responses`.
  - Calls `Oli.Delivery.Evaluation.Rule.parse_and_evaluate/2` for each response's string `rule`.
  - Produces a `FeedbackAction` from the selected response's score and feedback.
- `lib/oli/delivery/evaluation/rule.ex`
  - Parses and evaluates the legacy rule string grammar implemented in `lib/oli/delivery/evaluation/parser.ex`.

The activity model parser currently keeps response data in `Oli.Activities.Model.Response`, which includes:

- `id`
- `rule`
- `score`
- `feedback`
- `show_page`
- `correct`

It does not currently keep a `matchConfig` field or input metadata.

## Existing Response Selection Behavior

The current standard evaluator intentionally evaluates every configured response for a part and selects the highest-scoring response that matches. This is the behavior to preserve.

In `lib/oli/delivery/evaluation/evaluator.ex`, `consider_response/2` tracks the best matching response by score while still computing `out_of` from the maximum configured response score. If two matching responses have the same score, the earlier matching response remains selected because the replacement condition is strictly `best_score < score`.

The math integration must not change this reducer behavior. It should only change how an individual response answers "do I match this submitted input?" Add focused regression tests that pin highest-scoring-match behavior before introducing math matchers, including equal-score tie behavior and catch-all interactions.

## Integration Boundary

Add a new server-side matching boundary rather than embedding math details into the response reducer:

```text
Oli.Delivery.Evaluation.ResponseMatcher
  match?(response, context, part_metadata)
    -> {:ok, true}
    -> {:ok, false}
    -> {:error, reason}
```

The evaluator should continue to own response selection, score normalization, feedback action construction, targeted trigger checks, and lifecycle behavior. The matcher should only answer whether this response matches the submitted input.

Recommended responsibilities:

- `Oli.Delivery.Evaluation.Evaluator`
  - Owns response traversal and highest-scoring-match selection behavior.
  - Calls the matcher for each response.
  - Treats matcher errors like the current rule evaluator treats parse/evaluation errors: non-match unless the integration explicitly chooses to surface authoring/configuration errors in preview.
- `Oli.Delivery.Evaluation.ResponseMatcher`
  - Dispatches between new math config, legacy math/numeric adapters, and existing rule strings.
- `Oli.Delivery.Evaluation.MathMatcher`
  - Calls `Oli.Math.Equality`, `Oli.Math.Algebraic`, `Oli.Math.ExactForm`, and `Oli.Math.Units` as needed.
- `Oli.Delivery.Evaluation.LegacyMathRuleAdapter`
  - Converts existing rule strings and input-type metadata into the new math match config in memory.

## Response Storage Shape

For new authored `math_expression` inputs, add a response-level `matchConfig` field and omit the legacy `rule` field from serialized activity JSON:

```json
{
  "id": "r1",
  "matchConfig": {
    "version": 1,
    "mode": "expression",
    "comparison": {
      "type": "algebraic_equivalence",
      "expected": "1/2"
    },
    "form": {
      "type": "simplified_fraction"
    },
    "validation": {
      "allowedVariables": [],
      "allowedFunctions": [],
      "domains": []
    }
  },
  "score": 1,
  "feedback": "...",
  "correct": true
}
```

Do not keep `rule` present on new `math_expression` responses for compatibility. Having both `rule` and `matchConfig` on the same new response creates a future risk that some context reads the stale rule and evaluates the response through the wrong semantics.

For parsed Elixir structs, it is acceptable for `rule` to remain an in-memory field. `Oli.Activities.Model.Response.parse/1` should tolerate a missing serialized `"rule"` and assign `rule: ""` when `"matchConfig"` is present. The evaluator must not use that empty rule for `math_expression` responses.

Catch-all responses for new `math_expression` inputs should also use an explicit `matchConfig` matcher rather than a legacy regex rule. The config vocabulary should include a clear catch-all/always-match variant for this purpose.

The Elixir response model should be extended to preserve this optional field:

- Add `:match_config` to `Oli.Activities.Model.Response`.
- Parse from `"matchConfig"`.
- Allow serialized `"rule"` to be absent when `"matchConfig"` is present, assigning an empty in-memory `rule` value for struct compatibility.
- Encode/derive behavior should preserve the field where responses are serialized.
- Do not serialize `rule` for new `math_expression` responses.
- Do not require it for legacy responses.

## Input Metadata Required For Compatibility

Legacy Number and Math rule conversion requires knowing the input type for the part being evaluated.

That metadata is not currently available to `Oli.Delivery.Evaluation.Evaluator.evaluate/3`; it receives only a parsed `%Part{}` and an `EvaluationContext`.

Add part-level metadata during `Oli.Activities.Model.parse/1`:

- Short Answer:
  - Top-level `inputType` applies to the single authoring part.
  - Existing values include `text`, `numeric`, `textarea`, `math`, and `vlabvalue` in `assets/src/components/activities/short_answer/schema.ts`.
- Multi Input:
  - Top-level `inputs` contains items with `partId` and `inputType`.
  - Existing values include `dropdown`, `text`, `numeric`, and `math` in `assets/src/components/activities/multi_input/schema.ts`.

Recommended model addition:

```elixir
%Oli.Activities.Model.Part{
  id: "...",
  input_type: :math_expression | :numeric | :math | :text | :dropdown | nil,
  responses: [...]
}
```

Preserve the literal model vocabulary when parsing input types. Do not rename old stored `numeric` and `math` values to `legacy_numeric` or `legacy_math` in the parsed model. Those values are compatibility input types, but keeping their names aligned with existing activity JSON and existing code reduces risk. Use documentation and authoring UI constraints to mark `numeric` and `math` as deprecated for new authoring. Use `:math_expression` only for the new unified authored input type. Keep text/dropdown behavior on the existing rule-string path.

## New Math Expression Input Type

Add a new authoring/delivery input type named `math_expression`.

Behavior:

- New activities authored with expression-capable math should use `math_expression`.
- New `math_expression` responses should store `matchConfig` and should not store `rule`.
- The authoring UI should stop creating legacy `numeric` or legacy `math` input types for new math work.
- Existing `numeric` and `math` content remains supported at evaluation runtime without database migration.
- When an author opens an existing `numeric` or `math` input and saves changes, the authoring layer should convert that input to `math_expression`, translate the old rule-backed response configuration into `matchConfig`, and save the response without `rule`.

Compatibility rule:

- `inputType: "numeric"` means old stored Number semantics at evaluation runtime and should be converted to `math_expression` on the next authoring save.
- `inputType: "math"` means old stored LaTeX direct string semantics at evaluation runtime and should be converted to `math_expression` on the next authoring save.
- `inputType: "math_expression"` means the new unified math engine and response-level `matchConfig`.

## Unified Math Evaluation Contract

The long-term production API should be one Elixir boundary:

```elixir
Oli.Math.Equality.evaluate_response_config(equality_config, submitted)
```

It should return a match/non-match result plus structured diagnostics, but not score or feedback.

The current `Oli.Math.Equality` wrapper already calls `torus_math.decode_equality_config/1` and `torus_math.evaluate_equality/2`. Production integration should extend that boundary instead of having the evaluator call lower-level Gleam modules directly.

Required Gleam contract extensions before production integration:

- Expression mode must execute instead of returning `UnsupportedMode`.
- Unit-aware mode must execute instead of returning `UnsupportedMode`.
- Exact-form constraints should be represented in the match config, most likely as an optional `form` object on math expression configs.
- Add a legacy LaTeX direct comparison mode for old `inputType: "math"` content.
- Add an explicit catch-all/always-match response config for new `math_expression` catch-all responses.

Recommended expression comparison variants:

- `latex_direct`
  - Direct string comparison for legacy Math input compatibility only.
  - Must preserve the currently implemented legacy `input equals` behavior exactly, including whitespace normalization if the existing rule path performs it. The compatibility target should be tested against existing authored Math examples.
- `exact_expression`
  - Parsed expression exactness if product later wants parser-aware exact expression matching.
- `algebraic_equivalence`
  - Uses deterministic sampling-based equivalence.
- `algebraic_equivalence_with_form`
  - Runs semantic equivalence first, then exact-form constraints such as simplified fraction.
- `unit_aware`
  - Uses the unit comparison API and supported unit catalog.
- `always`
  - Matches any submitted value and exists to replace legacy catch-all rules for new `math_expression` responses.

## Legacy Numeric Rule Adapter

The legacy numeric adapter translates current rule strings into equality specs in memory. This belongs at the activity evaluator integration boundary, not in the core Gleam numeric evaluator.

Existing authoring construction lives in `assets/src/data/activities/model/rules.ts`; existing server semantics live in `lib/oli/delivery/evaluation/rule.ex`.

Mapping:

| Legacy rule shape | New comparison |
| --- | --- |
| `input = {x}` | `Numeric(Equal(x))` |
| `!(input = {x})` | `Numeric(NotEqual(x))` |
| `input > {x}` | `Numeric(GreaterThan(x))` |
| `input > {x} || input = {x}` | `Numeric(GreaterThanOrEqual(x))` |
| `input < {x}` | `Numeric(LessThan(x))` |
| `input < {x} || input = {x}` | `Numeric(LessThanOrEqual(x))` |
| `input = {[a,b]}` | `Numeric(Between(a, b, Inclusive))` |
| `input = {(a,b)}` | `Numeric(Between(a, b, Exclusive))` |
| `!(input = {[a,b]})` | `Numeric(NotBetween(a, b, Inclusive))` |
| `!(input = {(a,b)})` | `Numeric(NotBetween(a, b, Exclusive))` |
| `#n` suffix | `LegacySignificantFigures(n)` |

The adapter should use the existing server parser where possible:

```text
rule string -> Rule.parse/1 tree -> LegacyMathRuleAdapter.to_equality_config/2
```

Avoid ad hoc string parsing for production. The existing TypeScript parser helpers are useful documentation but must not be the server source of truth.

If a legacy numeric rule contains unsupported constructs, fall back to existing `Rule.parse_and_evaluate/2` for that response. This prevents the integration from breaking unusual existing content.

## Legacy Math Rule Adapter

Legacy Math inputs are authored as LaTeX strings through MathLive. Current short-answer creation uses:

```text
input equals {<escaped latex>}
```

For `inputType: "math"` and a simple `input equals {...}` rule:

- Convert to `Expression(LatexDirect(expected))`.
- Evaluate using the new Gleam direct-string comparison mode.
- Preserve escaping/unescaping behavior from the existing rule parser.
- Keep catch-all and non-simple text rules on the legacy rule path.

This mode should be documented as compatibility-only. New `math_expression` input authoring should not use LaTeX direct string comparison unless product explicitly exposes it as an advanced option.

## New Math Expression Response Examples

Full credit for simplified fraction:

```json
{
  "matchConfig": {
    "version": 1,
    "mode": "expression",
    "comparison": { "type": "algebraic_equivalence", "expected": "1/2" },
    "form": { "type": "simplified_fraction" }
  },
  "score": 1,
  "feedback": "Correct."
}
```

Partial credit for equivalent but unsimplified fraction:

```json
{
  "matchConfig": {
    "version": 1,
    "mode": "expression",
    "comparison": { "type": "algebraic_equivalence", "expected": "1/2" },
    "form": { "type": "fraction" }
  },
  "score": 0.5,
  "feedback": "Equivalent, but not simplified."
}
```

Catch-all:

```json
{
  "matchConfig": {
    "version": 1,
    "mode": "expression",
    "comparison": { "type": "always" }
  },
  "score": 0,
  "feedback": "Incorrect."
}
```

The response list still controls partial credit. The math engine only reports whether the submitted answer matches each response's config.

## Evaluation Algorithm

Target evaluator behavior:

```text
for response in part.responses:
  match =
    if response.matchConfig exists:
      MathMatcher.match?(response.matchConfig, submitted_input)
    else if part.input_type is numeric or math:
      LegacyMathRuleAdapter.try_match?(part.input_type, response.rule, submitted_input)
        fallback Rule.parse_and_evaluate(response.rule, context)
    else:
      Rule.parse_and_evaluate(response.rule, context)

  if match:
    keep response if no previous match exists or response.score is higher than current best

if best_response exists:
  return best_response score and feedback

return default incorrect feedback
```

This preserves the existing response list as the policy layer for score and feedback while preserving current highest-scoring-match selection.

## Preview, Test Eval, And Delivery

All standard evaluator entry points must use the same matcher:

- Real delivery: `evaluate_activity/4` -> `evaluate_from_input/5`.
- Author preview: `evaluate_from_preview/2`.
- Tool/test evaluation: `perform_test_eval/3`.

Do not add a separate math-only preview evaluator. It will drift from production response selection.

## Adaptive Activities

Do not route adaptive page rule evaluation through this integration in the first production slice.

Existing adaptive behavior in `lib/oli/delivery/attempts/activity_lifecycle/adaptive_part_evaluation.ex` and the screen rule evaluator should remain unchanged. If adaptive math support is needed later, treat it as a separate integration because adaptive state paths, screen-level scoring, and generated flowchart rules are a different contract.

## Error Handling

Production delivery should not show internal math diagnostics directly to students.

Recommended behavior:

- Config decode error on a response:
  - In production delivery, treat as non-match and continue to later responses, so catch-all feedback can still apply.
  - In author preview/test eval, preserve the current preview behavior in this work item. Do not add new diagnostic UI here.
- Submitted parse error:
  - Treat as non-match for the current response.
  - Let later responses handle targeted parse-error feedback if an author configured such a response.
- Unsupported legacy rule translation:
  - Fall back to existing string rule evaluation.
- Unexpected Gleam boundary failure:
  - Return non-match and log only aggregate-safe categories if production telemetry is added later. Do not log raw student input by default.

## Rollout Plan

1. Add response and part metadata plumbing.
   - Preserve optional `matchConfig` on parsed responses.
   - Annotate parsed parts with input type metadata for Short Answer and Multi Input.
   - Add parser tests for legacy numeric/math/expression input metadata.

2. Build the matcher boundary.
   - Add `ResponseMatcher`, `MathMatcher`, and `LegacyMathRuleAdapter`.
   - Keep existing rule evaluation as the fallback path.
   - Add evaluator tests proving non-math responses still behave unchanged.

3. Extend Gleam equality execution.
   - Make expression mode execute algebraic equivalence and exact-form constraints.
   - Make unit-aware mode execute unit comparison.
   - Add `latex_direct` compatibility mode.
   - Keep diagnostics structured and non-student-facing.

4. Add legacy numeric compatibility.
   - Translate parsed rule trees into numeric match configs.
   - Cover all existing Number operators and `#precision`.
   - Fall back safely for unsupported rule shapes.

5. Add legacy Math compatibility.
   - Translate simple `input equals {...}` LaTeX rules into direct-string configs.
   - Cover escaping and whitespace behavior with fixtures.

6. Add new Math Expression authoring.
   - Add the new input type to Short Answer and Multi Input authoring/delivery schemas.
   - Store `matchConfig` on new `math_expression` responses and omit serialized `rule`.
   - Convert existing `numeric` and `math` inputs to `math_expression` on authoring save, translating existing response rules into `matchConfig`.
   - Keep runtime compatibility for existing `numeric` and `math` content that is never edited and therefore remains rule-backed.

7. Add end-to-end verification.
   - Scenario or integration tests for Short Answer and Multi Input delivery.
   - Tests for full-credit simplified fraction, partial-credit unsimplified equivalent fraction, and catch-all incorrect response.
   - Tests for legacy numeric and legacy Math activities without database migration.

## Required Test Coverage

Server tests:

- `Oli.Activities.Model.parse/1` preserves `matchConfig`.
- `Oli.Activities.Model.Response.parse/1` accepts `math_expression` responses with missing serialized `rule` and assigns an empty in-memory rule.
- Part parsing annotates Short Answer `numeric`, `math`, and new `math_expression`.
- Part parsing annotates Multi Input per-part input types.
- `ResponseMatcher` uses `matchConfig` for `math_expression` responses and does not evaluate the empty in-memory rule.
- Legacy numeric rules convert to expected match configs for every current operator.
- Legacy numeric unsupported forms fall back to `Rule.parse_and_evaluate/2`.
- Legacy Math direct LaTeX comparison preserves current behavior.
- Highest-scoring-match response selection behavior is pinned, especially when more than one response matches.
- Catch-all still fires when no math response matches.

Gleam tests:

- JSON decode/encode for math expression configs with optional form constraints.
- JSON decode/encode for explicit math expression catch-all config.
- `latex_direct` match and mismatch.
- Algebraic equivalence mode returns matched/not matched.
- Exact-form failure returns not matched for the response.
- Unit-aware mode returns matched/not matched according to unit policy.

Integration/scenario tests:

- Short Answer `math_expression` full credit.
- Short Answer `math_expression` partial credit through response scoring and matcher specificity.
- Multi Input `math_expression` per-part scoring.
- Existing Short Answer numeric content still grades.
- Existing Short Answer Math content still grades.
- Existing Multi Input numeric/math content still grades.

## Resolved Decisions

- The new stored input type string is `math_expression`.
- The response-level stored matcher attribute is `matchConfig`.
- Legacy Math direct comparison preserves the behavior that is actually implemented today, including whitespace normalization if the current `input equals` path performs it.
- Author preview diagnostics remain unchanged in this work item; richer author-facing diagnostics are deferred to future work.
