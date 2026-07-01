# Math Evaluation Integration - Functional Design Document

## 1. Executive Summary

This design integrates the Gleam-based Torus Math evaluator into the existing standard activity evaluator as a response matching mechanism. It does not replace activity evaluation, scoring, feedback, targeted response behavior, rollups, persistence, or preview/test lifecycle behavior.

The core implementation is a new server-side matcher boundary. `Oli.Delivery.Evaluation.Evaluator` continues to evaluate every response for a part, track `out_of`, and select the highest-scoring matching response with earlier responses winning score ties. The new matcher only answers whether a response matches the submitted input.

New authored math-capable inputs use `inputType: "math_expression"` and response-level `matchConfig` objects. Those responses omit serialized `rule`. Existing `numeric` and `math` activity JSON remains valid indefinitely through runtime compatibility adapters, and edited legacy numeric/math content is converted to `math_expression` plus `matchConfig` on authoring save.

## 2. Requirements & Assumptions

- Functional requirements:
  - Preserve standard reducer semantics: all responses are considered, highest score wins, equal-score ties keep the earlier response. Covers AC-001, AC-002, AC-003.
  - Add response-level `matchConfig` support for new `math_expression` responses while omitting serialized `rule`. Covers AC-004, AC-005, AC-006, AC-007.
  - Annotate parsed parts with input metadata for Short Answer and Multi Input without renaming existing `numeric` or `math` values. Covers AC-008, AC-009, AC-010.
  - Introduce a matcher dispatch boundary for `matchConfig`, legacy numeric/math adapters, and existing rule evaluation. Covers AC-011, AC-012, AC-013, AC-014.
  - Execute new math matching through shared Gleam APIs for algebraic equivalence, exact form, unit-aware comparison, direct LaTeX compatibility, numeric compatibility, and always-match catch-alls. Covers AC-015, AC-016, AC-017, AC-018, AC-019.
  - Preserve runtime compatibility for legacy numeric and math rules. Covers AC-020, AC-021, AC-022, AC-023, AC-024, AC-025, AC-026, AC-027.
  - Convert edited legacy numeric/math authoring content to the new storage shape. Covers AC-028, AC-029, AC-030, AC-031.
  - Keep math diagnostics out of learner-facing feedback and avoid new author preview diagnostic surfaces. Covers AC-032, AC-033, AC-034.
  - Validate the integration across ExUnit, Gleam, frontend tests, and workflow/integration coverage. Covers AC-035, AC-036, AC-037, AC-038.
- Non-functional requirements:
  - No database-wide migration; published and unedited activity JSON remains rule-backed.
  - Deterministic shared math behavior across Gleam Erlang and JavaScript targets.
  - Bounded per-response evaluation cost in the existing evaluation loop.
  - No raw learner answers, sampled assignments, or detailed parser diagnostics in production logs or telemetry by default.
- Assumptions:
  - `math_expression` is the exact new input type string.
  - `matchConfig` is the exact serialized response field name.
  - `rule` may remain an in-memory Elixir struct field for compatibility, but it is not serialized for new `math_expression` responses.
  - Existing stored `numeric` and `math` input type strings remain valid and are not renamed to `legacy_numeric` or `legacy_math`.
  - Legacy Math direct comparison must preserve current `Rule.equals` behavior, including `Oli.Utils.normalize_whitespace/1` on submitted input where the existing rule path applies it.
  - Adaptive activity evaluation remains out of scope.

## 3. Repository Context Summary

- What we know:
  - Standard non-adaptive evaluation flows through `lib/oli/delivery/attempts/activity_lifecycle/evaluate.ex`, `lib/oli/delivery/attempts/activity_lifecycle/utils.ex`, `lib/oli/delivery/evaluation/standard.ex`, and `lib/oli/delivery/evaluation/evaluator.ex`.
  - `Oli.Delivery.Evaluation.Evaluator.consider_response/2` currently calls `Oli.Delivery.Evaluation.Rule.parse_and_evaluate/2` for every response and keeps the highest-scoring matching response.
  - Existing rule parsing/evaluation is in `lib/oli/delivery/evaluation/rule.ex` and `lib/oli/delivery/evaluation/parser.ex`.
  - Parsed response structs currently require `"rule"` and do not preserve `matchConfig`.
  - Parsed part structs currently do not carry delivery input type metadata.
  - Activity model parsing keeps `authoring.parts` as structured parts and preserves the rest of delivery/authoring model data as maps.
  - Shared math public functions are exposed through `gleam/src/torus_math.gleam` and thin Elixir wrappers such as `lib/oli/math/equality.ex`, `lib/oli/math/algebraic.ex`, `lib/oli/math/exact_form.ex`, and `lib/oli/math/units.ex`.
  - Short Answer and Multi Input schemas currently list `numeric` and `math` as valid input types in TypeScript authoring/delivery code.
- Resolved design findings:
  - Legacy Math input authoring is text-rule authoring with a MathLive editing surface. `assets/src/components/activities/short_answer/sections/MathInput.tsx` forces the text input operator to `equals`, and `assets/src/data/activities/model/rules.ts` constructs the same `input equals {...}` rule shape used by text equality.
  - Legacy Math defaults are created with `Responses.forMathInput()`, which uses `equalsRule('')`, and Short Answer math creation uses `equalsRule(creationData.answer)`. Regex, contains, and other text-style rules are therefore not a separate math grammar; unsupported math rules should stay on the existing rule evaluator.
  - Normal authoring saves do not serialize `%Oli.Activities.Model.Response{}` structs back to activity JSON. The browser sends the full activity model with `JSON.stringify` through `assets/src/data/persistence/activity.ts`, `OliWeb.Api.ActivityController.update/2` passes the decoded body map to `Oli.Authoring.Editing.ActivityEditor.edit/5`, and `Oli.Resources.Revision.changeset/2` casts `content` as a map.
  - Server-side parsed response structs are still critical for evaluation and preview/test evaluation, so they must decode `matchConfig` correctly and tolerate missing `rule`.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- `Oli.Delivery.Evaluation.Evaluator`
  - Keep current manual-grading branch unchanged.
  - Keep response traversal, best-response selection, `out_of` calculation, targeted response handling, score scaling, feedback action construction, trigger checks, and incorrect fallback unchanged.
  - Replace the direct `Rule.parse_and_evaluate(rule, context)` call inside `consider_response/2` with `ResponseMatcher.match?(response, context, part)`.

- `Oli.Delivery.Evaluation.ResponseMatcher`
  - New dispatch module that returns only match status:

    ```elixir
    @spec match?(Response.t(), EvaluationContext.t(), Part.t()) ::
            {:ok, boolean()} | {:error, term()}
    ```

  - Dispatch order:
    - If `response.match_config` is present, route to `Oli.Delivery.Evaluation.MathExpressionMatcher`.
    - If `part.input_type == "numeric"`, try `Oli.Delivery.Evaluation.LegacyNumericRuleAdapter`; fall back to `Rule.parse_and_evaluate/2` when unsupported.
    - If `part.input_type == "math"`, try `Oli.Delivery.Evaluation.LegacyMathRuleAdapter`; fall back to `Rule.parse_and_evaluate/2` when unsupported.
    - Otherwise route to `Rule.parse_and_evaluate/2`.
  - Treat matcher errors as non-matches in the evaluator, matching the current error posture for invalid rules.

- `Oli.Delivery.Evaluation.MathExpressionMatcher`
  - Accept a `matchConfig` map and the submitted input string.
  - Decode and evaluate through the Elixir math boundary.
  - Normalize Gleam result categories into `{:ok, true}`, `{:ok, false}`, or `{:error, reason}` without score or feedback.

- `Oli.Math.Match`
  - New production-facing Elixir wrapper for stored `matchConfig`.
  - It may delegate internally to existing `Oli.Math.Equality`, algebraic, exact-form, and units wrappers, but callers should not need to know the lower-level Gleam modules.
  - Public functions:

    ```elixir
    @spec decode_config(map() | String.t()) :: {:ok, term()} | {:error, term()}
    @spec evaluate_config(term(), String.t()) :: term()
    @spec evaluate_json(String.t(), String.t()) :: {:ok, term()} | {:error, term()}
    ```

- Gleam public API in `torus_math`
  - Add or evolve public functions around the production `matchConfig` envelope:
    - `decode_match_config(source: String)`
    - `encode_match_config(config)`
    - `evaluate_match(config, submitted: String)`
  - Existing equality, algebraic, exact-form, and units primitives remain internal building blocks.

- Frontend authoring modules
  - Extend Short Answer and Multi Input type unions to include `math_expression`.
  - Introduce match-config authoring helpers beside existing rule helpers rather than overloading `rules.ts`.
  - Load old numeric/math content into editable controls, but save as `math_expression` and `matchConfig`.

### 4.2 State & Data Flow

1. Authoring creates or updates an activity model.
2. New math-capable parts serialize delivery input metadata as `inputType: "math_expression"`.
3. New math expression responses serialize `matchConfig`, `score`, `feedback`, and response metadata, and omit `rule`.
4. Existing unedited content continues to serialize `inputType: "numeric"` or `inputType: "math"` with legacy `rule`.
5. On evaluation, `Oli.Activities.Model.parse/1` parses authoring parts and annotates each parsed part with the delivery input type string.
6. `Evaluator.evaluate/3` calls `ResponseMatcher.match?/3` for each response while preserving the existing reducer behavior.
7. `ResponseMatcher` routes new `matchConfig` responses to Gleam-backed math matching, old numeric/math responses to compatibility adapters, and all other responses to existing rule evaluation.
8. The selected response continues through existing feedback, score, trigger, persistence, rollup, snapshot, and experiment log paths.

### 4.3 Lifecycle & Ownership

- Activity JSON remains owned by existing authoring and resource revision flows.
- Published activity JSON is immutable through the publication model; this work does not mutate old publications.
- Runtime compatibility belongs to the delivery evaluator boundary because old content may be evaluated forever.
- Edit-time conversion belongs to activity authoring because saving a revision is the moment a mutable authoring model can move forward to the new shape.
- Math parsing/evaluation semantics belong to Gleam; Elixir and TypeScript should only call public wrappers or construct documented config shapes.

### 4.4 Alternatives Considered

- Embed math handling directly in `Evaluator.consider_response/2`.
  - Rejected because it would mix response selection policy with math-specific matching and make compatibility fallback harder to test.
- Keep serialized `rule` on new math expression responses.
  - Rejected because stale fallback rules could be consumed by other paths and produce incorrect matches.
- Rename parsed old input types to `legacy_numeric` and `legacy_math`.
  - Rejected because stored JSON and existing code already use `numeric` and `math`; preserving literal vocabulary reduces compatibility risk.
- Run a database migration to convert all old activities.
  - Rejected because published content is intentionally stable and old content can remain unedited indefinitely.
- Make author preview expose detailed math diagnostics now.
  - Rejected for this work item; preview should keep existing behavior and richer author diagnostics can be designed separately.

## 5. Interfaces

- `Oli.Activities.Model.Response`
  - Add `:match_config`.
  - Parse `"matchConfig"` into `match_config`.
  - Accept missing `"rule"` only when `"matchConfig"` is present; assign `rule: ""` in memory.
  - Continue requiring `"rule"` for legacy responses that do not have `matchConfig`.

- `Oli.Activities.Model.Part`
  - Add `:input_type`.
  - Store the literal input type string, not an atom. Expected values include `"text"`, `"textarea"`, `"vlabvalue"`, `"dropdown"`, `"numeric"`, `"math"`, and `"math_expression"`.

- `Oli.Activities.Model.parse/1`
  - For Short Answer, read top-level delivery `"inputType"` and apply it to the parsed authoring part.
  - For Multi Input, read delivery `"inputs"` and map each `%{"partId" => part_id, "inputType" => input_type}` to the matching parsed authoring part.
  - Preserve unknown input type strings as strings and let matcher dispatch fall back to legacy rule evaluation unless a supported `matchConfig` is present.

- `Oli.Delivery.Evaluation.ResponseMatcher.match?/3`
  - The only evaluator-facing matching API.
  - It does not return score, feedback, triggers, or diagnostics intended for learners.

- `Oli.Delivery.Evaluation.LegacyNumericRuleAdapter`
  - Input: legacy rule string plus evaluation context.
  - Uses `Rule.parse/1` to inspect the parsed rule tree.
  - Converts supported numeric shapes to in-memory math configs and evaluates through `Oli.Math.Match`.
  - Returns `:unsupported` for unknown rule trees so the dispatcher can fall back to `Rule.parse_and_evaluate/2`.

- `Oli.Delivery.Evaluation.LegacyMathRuleAdapter`
  - Input: legacy rule string plus evaluation context.
  - Converts simple `input equals {...}` or input-ref equals rules into direct LaTeX comparison configs.
  - Preserves existing parser escaping/unescaping and submitted-input whitespace normalization.
  - Returns `:unsupported` for catch-all, regex, contains, case-insensitive equality, compound, or non-simple math rules so the dispatcher can fall back to `Rule.parse_and_evaluate/2`.
  - This is intentionally the same fallback posture as text input rules because the legacy Math input type is a text-rule matcher over a LaTeX string.

- TypeScript config types
  - Add a shared `MatchConfig` type for activity authoring JSON.
  - Keep legacy rule helpers for text/dropdown and for reading old numeric/math models.
  - Add conversion helpers:

    ```ts
    legacyNumericRuleToMatchConfig(rule: string): MatchConfig | undefined
    legacyMathRuleToMatchConfig(rule: string): MatchConfig | undefined
    responseWithMatchConfig(response, config): responseWithoutRule
    ```

## 6. Data Model & Storage

- No database schema changes are required.
- The activity model JSON stored on resource revisions is the only storage shape affected.
- New response storage shape:

  ```json
  {
    "id": "response-1",
    "matchConfig": {
      "version": 1,
      "type": "math_expression",
      "math": {
        "mode": "algebraic_equivalence",
        "expected": "1/2",
        "form": { "type": "simplified_fraction" },
        "validation": { "allowedVariables": [] }
      }
    },
    "score": 1,
    "feedback": { "id": "feedback-1", "content": [{ "type": "p", "children": [{ "text": "Correct." }] }] },
    "correct": true
  }
  ```

- Always-match catch-all shape:

  ```json
  {
    "version": 1,
    "type": "always"
  }
  ```

- Direct LaTeX compatibility shape:

  ```json
  {
    "version": 1,
    "type": "math_expression",
    "math": {
      "mode": "latex_direct",
      "expected": "\\frac{1}{2}",
      "compatibility": "legacy_math"
    }
  }
  ```

- Unit-aware shape:

  ```json
  {
    "version": 1,
    "type": "math_expression",
    "math": {
      "mode": "unit_aware",
      "expected": "9.8 m/s^2",
      "unitPolicy": { "type": "convertible_units", "units": ["m/s^2", "ft/s^2"] },
      "tolerance": { "type": "absolute_or_relative", "abs": 0.0001, "rel": 0.0001 }
    }
  }
  ```

- Numeric compatibility shape for converted authoring content:

  ```json
  {
    "version": 1,
    "type": "math_expression",
    "math": {
      "mode": "numeric",
      "operator": "equal",
      "expected": "3.20",
      "precision": { "type": "significant_figures", "count": 3 }
    }
  }
  ```

- Existing stored legacy response shape remains valid:

  ```json
  {
    "id": "response-1",
    "rule": "input = {3#1}",
    "score": 1,
    "feedback": "...",
    "correct": true
  }
  ```

- Serialization rule:
  - New `math_expression` responses must not include `rule`.
  - Legacy unedited responses may continue to include `rule`.
  - If a response includes both fields due to malformed authoring, `matchConfig` takes precedence during matching and the condition should be covered by tests.
  - Browser-side activity saves must preserve `matchConfig` through `JSON.stringify` of the full activity model.
  - Server-side activity saves must preserve `matchConfig` as plain nested map data in revision `content`; evaluation-side structs must decode that map from `"matchConfig"` into `response.match_config`.

## 7. Consistency & Transactions

- Evaluation transaction boundaries remain unchanged in `evaluate_from_input/5`.
- The matcher does not write database state and should not introduce new transaction work.
- Authoring conversion is part of normal activity save/revision updates. The saved revision should contain a self-consistent model where converted inputs use `inputType: "math_expression"` and converted responses use `matchConfig` without `rule`.
- No background migration, Oban job, or publication update task is introduced.

## 8. Caching Strategy

- No global cache is required for the MVP.
- Parsed `matchConfig` may be decoded per response evaluation. This is bounded by the existing number of responses per part.
- Implementation may normalize/prepare configs during `Model.parse/1` only if it remains deterministic, local to the parsed model, and does not change the serialized model.
- Unit catalog data remains the hardcoded Gleam catalog and does not require application-level caching.

## 9. Performance & Scalability Posture

- The hot path remains the existing per-submitted-part response loop.
- Matching cost increases only for responses that use `matchConfig` or legacy numeric/math adapters.
- The first implementation should keep math evaluator sample counts bounded by the existing Gleam equality configuration defaults.
- Fallback to `Rule.parse_and_evaluate/2` preserves current performance for unsupported or non-math responses.
- Review focus:
  - avoid repeated JSON encode/decode work when a response already carries a map;
  - avoid logging large diagnostics in response-heavy evaluations;
  - keep unit and algebraic evaluation deterministic and bounded.

## 10. Failure Modes & Resilience

- Invalid `matchConfig`:
  - Return `{:error, :invalid_config}` from the math boundary.
  - Evaluator treats it as a non-match.
  - Learner sees normal authored fallback feedback if another response matches, or the existing incorrect fallback if none match.
- Invalid learner submission:
  - Return a structured non-match or invalid-submission result from Gleam.
  - Do not expose raw parser details to learners.
- Unsupported legacy numeric rule:
  - Adapter returns `:unsupported`.
  - Dispatcher falls back to `Rule.parse_and_evaluate/2`.
- Unsupported legacy math rule:
  - Adapter returns `:unsupported`.
  - Dispatcher falls back to `Rule.parse_and_evaluate/2`.
- Gleam wrapper exception or unexpected result:
  - Catch at the Elixir wrapper or matcher boundary and return a matcher error.
  - Do not crash the standard evaluation transaction for one malformed response unless existing evaluator behavior would already fail.
- Missing input metadata:
  - If `matchConfig` exists, use it.
  - Otherwise fall back to legacy rule evaluation.

## 11. Observability

- No new author or learner diagnostics are added in this work item.
- If telemetry is added, use aggregate-safe fields only:
  - input type;
  - match config mode;
  - match outcome category;
  - invalid config category;
  - elapsed-time bucket.
- Do not log raw learner submissions, raw expected answers, sampled variable assignments, or detailed parser traces by default.
- AppSignal and standard Phoenix telemetry can be used to inspect latency/error rates after rollout.

## 12. Security & Privacy

- The matcher must not bypass existing authorization or delivery lifecycle paths; it only runs inside existing activity evaluation.
- Math engine diagnostics are treated as internal data and are not rendered directly in learner delivery.
- Logs and telemetry must avoid raw learner answers and detailed diagnostics by default.
- `matchConfig` should be decoded structurally and reject unknown/invalid config forms rather than evaluating arbitrary code or dynamically calling functions by name.
- Preserve existing content publication rules: delivery evaluates the resolved published activity model, not mutable authoring state.

## 13. Testing Strategy

- ExUnit tests:
  - `Oli.Activities.Model.Response.parse/1` accepts `matchConfig` without `rule`, assigns empty in-memory `rule`, and preserves legacy responses.
  - `Oli.Activities.Model.parse/1` annotates Short Answer parts from top-level `inputType`.
  - `Oli.Activities.Model.parse/1` annotates Multi Input parts from `inputs[].partId`.
  - `Evaluator.evaluate/3` preserves highest-scoring match selection and equal-score earlier-response tie behavior.
  - `ResponseMatcher` dispatches `matchConfig` responses to math, text/dropdown to `Rule.parse_and_evaluate/2`, and legacy numeric/math to adapters.
  - Legacy numeric adapter parity tests compare supported rule strings against current `Rule.parse_and_evaluate/2`, including significant figures.
  - Legacy math adapter parity tests compare direct LaTeX equals rules against current `Rule.parse_and_evaluate/2`, including escaping and whitespace behavior.

- Gleam tests:
  - Run `gleam test --target erlang` and `gleam test --target javascript`.
  - Cover `decode_match_config`, `evaluate_match`, algebraic equivalence, exact-form constraints, unit-aware comparison, direct LaTeX compatibility, numeric significant figures, invalid config, invalid submission, and always-match.

- Frontend tests:
  - Short Answer schema accepts `math_expression`.
  - Multi Input schema accepts `math_expression`.
  - New authoring produces `inputType: "math_expression"` and `matchConfig` responses without `rule`.
  - Editing/saving legacy numeric converts to `math_expression` and equivalent `matchConfig`.
  - Editing/saving legacy math converts to `math_expression` and direct LaTeX `matchConfig`.
  - Full activity-model serialization tests cover `JSON.stringify`/`JSON.parse` of a Short Answer and Multi Input model containing response `matchConfig`; the parsed object must still omit `rule` on new math expression responses and preserve nested match config fields exactly.

- Integration/scenario tests:
  - Author, publish, deliver, and submit a new `math_expression` activity with full-credit, partial-credit, and always-match responses.
  - Deliver old unedited numeric and math content and verify response feedback/score parity.
  - Include at least one unit-aware response and one exact-form response in workflow coverage.
  - Add an Elixir full-model persistence/parse test that sends or simulates the same update shape as `assets/src/data/persistence/activity.ts`, stores revision `content` as a map, reloads the revision, parses it with `Oli.Activities.Model.parse/1`, and verifies `response.match_config` can be evaluated through the matcher.
  - Add a preview/test-eval full-model test using an activity model with `matchConfig` to prove whole-activity decoding, part metadata annotation, and matcher evaluation work together.

- Validation commands for implementation slices:
  - `mix test` for targeted Elixir tests.
  - `cd gleam && gleam test --target erlang`.
  - `cd gleam && gleam test --target javascript`.
  - `cd assets && yarn test` for targeted frontend tests.
  - Scenario validation and targeted scenario runner when scenario files are added.

## 14. Backwards Compatibility

- Existing `numeric` and `math` stored input types remain valid at runtime.
- Existing old responses without `matchConfig` continue through `Rule.parse_and_evaluate/2` unless a supported legacy adapter can safely translate them to the math engine.
- Unsupported old rule shapes always fall back to the current rule evaluator.
- Existing text, textarea, dropdown, vlabvalue, and non-math behavior remains rule-backed.
- Existing standard evaluation entry points continue using the same path for delivery, preview, and test evaluation.
- Edited legacy numeric/math authoring content is converted only when saved as a new revision.

## 15. Risks & Mitigations

- Risk: A stale or empty rule is evaluated for a new `math_expression` response.
  - Mitigation: `ResponseMatcher` gives `matchConfig` precedence and tests assert the empty in-memory rule is not evaluated.
- Risk: Legacy numeric compatibility diverges from existing `Rule` behavior.
  - Mitigation: Build the adapter from `Rule.parse/1` trees and add parity tests against `Rule.parse_and_evaluate/2`.
- Risk: Legacy Math direct comparison changes whitespace or escaping behavior.
  - Mitigation: Preserve the same submitted-input extraction and whitespace normalization used by `Rule.eval/2`; add tests for escaped braces, backslashes, and whitespace.
- Risk: Authoring conversion writes mixed models with both old input types and new match configs.
  - Mitigation: Centralize conversion helpers and assert saved JSON has `inputType: "math_expression"` plus `matchConfig` without `rule`.
- Risk: Math evaluation leaks raw answers through diagnostics.
  - Mitigation: Keep diagnostics internal, avoid raw telemetry/log fields, and keep preview diagnostic behavior unchanged.
- Risk: Response-heavy activities see latency increases.
  - Mitigation: Keep sampling/config bounds explicit, avoid repeated unnecessary serialization, and include performance review before release.

## 16. Open Questions & Follow-ups

- None for this FDD.
- Future follow-up: design richer author-preview diagnostics for math response authoring. This work intentionally keeps preview diagnostics unchanged.

## 17. References

- `docs/exec-plans/current/epics/math/integration/prd.md`
- `docs/exec-plans/current/epics/math/integration/approach.md`
- `docs/exec-plans/current/epics/math/integration/requirements.yml`
- `ARCHITECTURE.md`
- `harness.yml`
- `docs/STACK.md`
- `docs/TOOLING.md`
- `docs/TESTING.md`
- `docs/PRODUCT_SENSE.md`
- `docs/FRONTEND.md`
- `docs/BACKEND.md`
- `docs/DESIGN.md`
- `docs/OPERATIONS.md`
- `docs/CODEREVIEW.md`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- `lib/oli/delivery/evaluation/evaluator.ex`
- `lib/oli/delivery/evaluation/rule.ex`
- `lib/oli/activities/model.ex`
- `lib/oli/activities/model/part.ex`
- `lib/oli/activities/model/response.ex`
- `lib/oli/math/equality.ex`
- `gleam/src/torus_math.gleam`
- `assets/src/components/activities/short_answer/schema.ts`
- `assets/src/components/activities/multi_input/schema.ts`
- `assets/src/data/activities/model/rules.ts`
