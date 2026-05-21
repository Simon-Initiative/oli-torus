# Algebraic Expression Equivalence - Informal PRD And Technical Approach

## 1. Executive Summary

Implement **Algebraic Expression Equivalence** as the next semantic layer of the Torus Math feature. This feature uses the already-completed parser, normalization layer, deterministic evaluator, seeded sampler, variable domain model, and numeric tolerance helper to answer one central question:

> Does the student's expression behave the same as the expected expression over the configured domain, within configured numeric tolerance?

This is the first feature that compares **two expressions** as mathematical objects. It is not a symbolic algebra system, and it is not a general-purpose CAS. The feature should use **normalization plus deterministic sampling** to provide practical, predictable, explainable equivalence checking for Math Expression inputs.

The design should be very intentional about scope. The parser decides whether strings are syntactically valid. The normalizer creates stable structural forms. The sampler and evaluator produce deterministic numeric values at concrete assignments. **Algebraic equivalence is the policy layer that orchestrates those pieces.**

This work should also update the existing developer-only Math Prototype LiveView with an **Algebraic Equivalence** panel. The prototype UI should allow developers to enter two expressions, configure the equivalence check, click **Check Equivalence**, and inspect the structured result, normalized forms, sample assignments, evaluated values, differences, and rejection diagnostics.

## 2. Product Goal

The product goal is to support the future Math Expression response mode where students can enter expressions such as:

```text
2x + 6
```

and receive credit when the expected answer is:

```text
2(x + 3)
```

The feature should accept mathematically equivalent expressions without relying on fragile string matching or exact written form. It should also reject near misses such as:

```text
2x + 7
```

and distinguish that rejection from syntax errors, invalid variables, domain problems, unsupported functions, and insufficient sampling.

This feature is the bridge between low-level math infrastructure and the future student-facing Math Expression evaluator.

## 3. Why This Comes Now

This feature depends directly on the prior layers:

1. **Parser**
   - Converts ASCII/calculator-style strings into ASTs.
   - Produces structured parse errors with spans.

2. **Normalization**
   - Converts parsed ASTs into stable internal expression structures.
   - Performs structural canonicalization without broad symbolic simplification.

3. **Deterministic expression evaluation and sampling**
   - Evaluates normalized expressions at concrete variable assignments.
   - Generates seeded, repeatable sample assignments.
   - Handles variable domains, invalid runtime math operations, retry behavior, and numeric tolerance comparison.

Algebraic equivalence should not reimplement these lower layers. It should compose them.

The previous sampling feature intentionally stopped short of final equivalence. This feature is where expected-versus-candidate comparison becomes real.

## 4. Strong Product Position

The MVP equivalence feature should be opinionated:

> Algebraic equivalence means value equivalence over the configured domain, tested by deterministic sampling and numeric tolerance.

That means:

- It is **not** exact string equality.
- It is **not** exact form equality.
- It is **not** full symbolic proof.
- It is **not** generic simplification.
- It is **not** domain-equivalence proof across all real numbers.
- It is a deterministic, testable, sampling-based equality policy suitable for common authored algebraic answers.

The correct mental model is:

```text
For each deterministic sample assignment:
  evaluate expected expression
  evaluate candidate expression
  compare the two numeric values using tolerance

If all required valid samples pass:
  equivalent
else:
  not equivalent or structured failure
```

## 5. MVP Scope

### In scope

- Equivalent expression mode for Math Expression inputs.
- Comparing an expected expression string with a candidate expression string.
- Parsing and normalizing both expressions through existing shared Gleam functionality.
- Allowed-variable validation before sampling.
- Allowed-function validation before sampling, if that validation already exists or is easy to reuse.
- Determining the variable set to sample.
- Evaluating both expressions over the same deterministic sample assignments.
- Reusing the existing numeric tolerance comparison helper.
- Handling expected-expression runtime errors during sampling by rejecting/retrying those sample points.
- Handling candidate-expression runtime errors at expected-valid sample points as evidence of non-equivalence.
- Returning structured outcomes rather than booleans only.
- Stable debug formatting for developer tooling and golden tests.
- Cross-target parity under Erlang and JavaScript Gleam tests.
- Prototype UI support in the existing Math Prototype LiveView.

### Out of scope

- Production integration into Short Answer or Multi-Input grading.
- Production student UI changes.
- Production authoring UI changes.
- Units and unit-aware equivalence.
- Exact-form grading.
- Partial credit.
- Feedback-rule matching.
- CAS-style simplification.
- Expansion/factoring as an equivalence dependency.
- Rational function canonicalization with preserved domain guards.
- Complex numbers.
- Piecewise expressions.
- Symbolic proof of identities.
- Strict mathematical proof of domain equivalence.
- Adaptive activity evaluation integration.

## 6. User Stories

### Developer story: inspect equivalence

As a developer, I want to enter two expressions in the Math Prototype LiveView and check whether they are algebraically equivalent, so that I can validate the behavior of parser, normalization, sampling, evaluation, and tolerance comparison together.

### Developer story: debug a failure

As a developer, I want to see the first failing sample assignment, expected value, candidate value, numeric difference, and tolerance decision, so that I can understand why two expressions were not considered equivalent.

### Developer story: diagnose domain issues

As a developer, I want runtime math errors and rejected sample summaries to be categorized, so that I can distinguish a genuinely wrong answer from a bad domain configuration or insufficient valid sample generation.

### Future author story: preview candidate answers

As an author, I will eventually want to type sample student answers against an expected expression and see whether they would pass. This MVP does not build the authoring UI, but the prototype should produce the diagnostics needed for that future surface.

### Future student story: receive correct credit

As a student, I will eventually want `2x + 6` to be accepted when the expected answer is `2(x + 3)`, and I will not want grading to depend on the exact written form I used.

## 7. Guiding Principles

### 7.1 Equivalence is a policy layer

Do not bury equivalence logic inside the sampler, evaluator, parser, or normalizer.

The equivalence module owns orchestration:

```text
parse
normalize
validate
sample
evaluate expected
evaluate candidate
compare
summarize outcome
```

The lower layers should remain reusable independently.

### 7.2 Same assignments, both expressions

Expected and candidate expressions must be evaluated against the **same assignments**. If the expected expression is checked at `x = 2.5`, the candidate must also be checked at `x = 2.5`.

Do not generate separate sample sets for each expression.

### 7.3 Determinism is mandatory

Given the same:

- expected expression,
- candidate expression,
- config,
- domains,
- seed,
- sample count,
- tolerance,

this feature must return the same result every time on both Erlang and JavaScript targets.

### 7.4 Structured outcomes matter more than a single boolean

The public result should include a high-level outcome, but internally and in prototype/debug surfaces it must expose structured details.

For example:

```text
Equivalent
NotEquivalent
ExpectedParseError
CandidateParseError
ValidationError
InsufficientValidSamples
CandidateUndefinedAtSample
```

These should not collapse into a vague `false`.

### 7.5 Do not pretend sampling is proof

Sampling is a practical equivalence method. It is strong for many common algebraic cases, especially polynomials and routine identities, but it can miss rare-point differences or adversarial expressions.

The product should describe this internally as deterministic sampling-based equivalence, not as universal symbolic proof.

### 7.6 Preserve privacy boundaries

Prototype debug output may show raw expressions and sample assignments because it is developer-only. Production telemetry should not log raw learner expressions or raw sampled assignments by default.

## 8. Equivalence Semantics

### 8.1 Default semantic contract

The default MVP contract should be:

> Two expressions are algebraically equivalent if, for the requested number of valid sample assignments inside the configured domain, both expressions evaluate successfully and their values compare equal within configured tolerance.

More precisely:

1. Generate candidate assignments from the configured variable domains and seed.
2. Reject/retry assignments where the **expected expression** cannot be evaluated.
3. For each expected-valid assignment, evaluate the candidate expression.
4. If the candidate cannot be evaluated at an expected-valid assignment, return a non-equivalence/domain outcome.
5. If both evaluate, compare numeric values using the configured tolerance.
6. If any comparison fails, return `NotEquivalent` with details.
7. If enough valid samples pass, return `Equivalent`.

### 8.2 Domain interpretation

MVP equivalence should be understood as:

> Equivalence over the configured domain where the expected expression is defined.

This is an important, opinionated choice.

Example:

```text
expected: 1 / x
candidate: x^-1
```

These should pass over a domain that excludes or retries `x = 0`.

Example:

```text
expected: x / x
candidate: 1
```

Under this MVP policy, this may pass because `x = 0` is not a valid expected-expression sample point. This does **not** prove that the two expressions have identical domains over all real numbers. It proves value equivalence over valid expected samples from the configured domain.

This is acceptable for MVP because many educational equivalence checks care about simplified value behavior over the intended domain. Strict domain-equivalence proof should be a future, explicit mode.

### 8.3 Candidate domain narrowing

If the expected expression is defined at a sample point but the candidate expression is not, the candidate should fail.

Example:

```text
expected: x
candidate: 1 / (1 / x)
```

At `x = 0`:

```text
expected: 0
candidate: undefined
```

If `x = 0` is included as an expected-valid sample, the result should be non-equivalence.

### 8.4 Expected invalid samples

If the expected expression is invalid at a generated sample point, that sample point should generally be rejected and retried, not treated as a student failure.

Example:

```text
expected: 1 / x
candidate: x^-1
sample: x = 0
```

The expected expression is undefined, so `x = 0` is not useful for evaluating equivalence under the expected expression's valid domain. The executor should retry.

### 8.5 Both invalid samples

If both expressions are invalid at a sample point, that sample point should be rejected and retried. It proves neither equivalence nor non-equivalence.

### 8.6 Constant expressions

If neither expression has variables, equivalence should not require random sampling.

Example:

```text
expected: sqrt(2) / 2
candidate: 1 / sqrt(2)
```

The equivalence checker can evaluate each once under an empty assignment and compare using tolerance.

The result details should still use a sample-like structure for consistency, perhaps with one synthetic assignment:

```text
assignment: {}
source: ConstantExpression
```

### 8.7 Candidate has extra variables

If the candidate expression uses variables that are not allowed by the equivalence config, return validation failure before sampling.

Example:

```text
expected: x + 1
candidate: x + y
allowed variables: [x]
```

Result:

```text
ValidationError: unexpected variable y
```

If `y` is allowed, the checker may sample both `x` and `y`. In that case, `x + y` will generally fail against `x + 1` unless the sampled values make `y = 1` by coincidence. The sampler should avoid pathological correlated values and should include enough samples to catch this.

### 8.8 Expected has variables absent from candidate

This is allowed.

Example:

```text
expected: x - x
candidate: 0
```

The sampler should sample `x`; the candidate simply ignores it.

### 8.9 Functions and constants

Equivalence should support the same real-valued functions already supported by deterministic evaluation:

```text
sin, cos, tan, ln, log, log10, log2, sqrt, abs, exp
```

Constants:

```text
pi, e
```

Trigonometric functions should use radians.

### 8.10 Tolerance

All numeric comparisons should reuse the existing tolerance helper from the sampling/evaluation layer.

Default recommendation:

```text
AbsoluteOrRelativeTolerance(abs: 0.0001, rel: 0.0001, epsilon: small floor)
```

This default is intentionally somewhat forgiving for early expression equivalence. Authors or future UI controls can tighten it.

## 9. Proposed Module Layout

Use the existing `gleam/src/math/` structure. Because algebraic equivalence is an equality mode, implement it under `math/equality` rather than creating a competing top-level concept.

Recommended additions:

```text
gleam/src/math/equality/algebraic.gleam
gleam/src/math/equality/algebraic_types.gleam
gleam/src/math/equality/algebraic_format.gleam
gleam/src/math/equality/pipeline.gleam
```

Possible test files:

```text
gleam/test/math/equality/algebraic_test.gleam
gleam/test/math/equality/algebraic_golden_test.gleam
gleam/test/math/equality/algebraic_cross_target_test.gleam
```

If the existing repository prefers flatter test paths, adapt names accordingly, but keep the conceptual boundary clear.

### Module responsibilities

#### `algebraic_types.gleam`

Owns equivalence config, result, diagnostics, sample comparison details, and error taxonomy.

#### `pipeline.gleam`

Owns reusable helpers for:

- parsing expression strings,
- normalizing parsed expressions,
- validating variables/functions,
- collecting variable names,
- constructing effective domains.

This module should not make equivalence decisions.

#### `algebraic.gleam`

Owns the equivalence algorithm.

This is where expected and candidate expressions are compared over deterministic samples.

#### `algebraic_format.gleam`

Owns stable debug formatting for equivalence results.

Do not use target-specific inspect formatting for stable output.

#### `torus_math.gleam`

Expose a small public API. Torus callers and prototype wrappers should use this boundary.

## 10. Public API Shape

The feature should expose two levels of API:

1. **Raw-string API** for prototype UI and future author preview.
2. **Normalized-expression API** for lower-level tests and future internal integration.

### 10.1 Raw-string API

```gleam
pub fn check_algebraic_equivalence(
  expected: String,
  candidate: String,
  config: AlgebraicEquivalenceConfig,
) -> AlgebraicEquivalenceResult
```

This function should:

- parse expected,
- parse candidate,
- normalize expected,
- normalize candidate,
- validate variables/functions,
- run sampling/evaluation/comparison,
- return structured result.

This is the most useful API for the prototype UI.

### 10.2 Normalized-expression API

```gleam
pub fn check_normalized_algebraic_equivalence(
  expected: normalization_types.NormalExpr,
  candidate: normalization_types.NormalExpr,
  config: AlgebraicEquivalenceConfig,
) -> AlgebraicEquivalenceResult
```

This function assumes parsing and normalization have already happened.

This is useful for tests and future integration where parsed/normalized values may already exist.

### 10.3 Defaults

```gleam
pub fn default_algebraic_equivalence_config() -> AlgebraicEquivalenceConfig
```

Default config should be appropriate for common algebraic expression checking:

- sample count: 8
- max attempts: 64 or 100
- seed: stable default, such as `42`
- default domain: `[-10, 10]`
- include special points: true
- tolerance: default expression tolerance from sampling layer
- allowed variables: infer from expected expression unless explicitly configured
- allowed functions: supported MVP function list

## 11. Config Model

The config should be explicit and JSON-encodable later, but it does not need full production JSON storage in this phase.

Suggested shape:

```gleam
pub type AlgebraicEquivalenceConfig {
  AlgebraicEquivalenceConfig(
    allowed_variables: AllowedVariables,
    allowed_functions: AllowedFunctions,
    domains: sampling_types.DomainConfig,
    sampling: sampling_types.SamplingConfig,
    eval: sampling_types.EvalConfig,
    tolerance: sampling_types.Tolerance,
    domain_policy: DomainPolicy,
    diagnostics: DiagnosticLevel,
  )
}
```

### 11.1 Allowed variables

```gleam
pub type AllowedVariables {
  InferFromExpected
  ExplicitAllowedVariables(List(String))
}
```

Default should be `InferFromExpected`.

If expected is:

```text
2x + 6
```

then `x` is allowed, and candidate variables outside `[x]` should fail validation.

This matches likely author expectations. If an author wants to allow extra variables because they cancel out, they can explicitly allow them later.

Example:

```text
expected: x
candidate: x + y - y
```

Default inferred variables would reject `y`. Explicit allowed variables `[x, y]` would allow sampling both variables and likely accept the identity.

This is a product decision. The default should favor clarity for authors over cleverness.

### 11.2 Allowed functions

```gleam
pub type AllowedFunctions {
  DefaultSupportedFunctions
  ExplicitAllowedFunctions(List(FunctionName))
}
```

Default should be all currently supported MVP functions.

Future authoring UI may restrict functions per item. This phase can include the type and default behavior without building production UI.

### 11.3 Domain policy

```gleam
pub type DomainPolicy {
  ExpectedDefinedDomain
}
```

For MVP, only support `ExpectedDefinedDomain`.

This means:

- sample points where expected is undefined are rejected/retried;
- sample points where expected is defined and candidate is undefined fail the candidate;
- strict domain-equivalence proof is out of scope.

A future mode might be:

```gleam
StrictDomainCompatibility
```

but do not implement it now unless the current evaluator and sampler can do it cleanly.

### 11.4 Diagnostic level

```gleam
pub type DiagnosticLevel {
  SummaryDiagnostics
  DetailedDiagnostics
}
```

For prototype UI, use detailed diagnostics.

For future production grading, summary diagnostics may be enough.

## 12. Result Model

The result should not be a bare boolean.

Suggested high-level type:

```gleam
pub type AlgebraicEquivalenceResult {
  AlgebraicEquivalenceResult(
    outcome: AlgebraicEquivalenceOutcome,
    expected_debug: Option(ExpressionDebug),
    candidate_debug: Option(ExpressionDebug),
    samples: List(SampleComparison),
    rejected_samples: List(RejectedSampleSummary),
    config_summary: EquivalenceConfigSummary,
  )
}
```

### 12.1 Outcome taxonomy

```gleam
pub type AlgebraicEquivalenceOutcome {
  Equivalent(valid_sample_count: Int)
  NotEquivalent(reason: NonEquivalenceReason)
  ExpectedParseFailed(error: ParseError)
  CandidateParseFailed(error: ParseError)
  ExpectedNormalizationFailed(description: String)
  CandidateNormalizationFailed(description: String)
  ValidationFailed(errors: List(EquivalenceValidationError))
  InsufficientValidSamples(error: sampling_types.SamplingError)
}
```

### 12.2 Non-equivalence reasons

```gleam
pub type NonEquivalenceReason {
  ValueMismatch(first_failure: SampleComparison)
  CandidateUndefined(first_failure: CandidateRuntimeFailure)
  UnsupportedEvaluation(description: String)
}
```

### 12.3 Sample comparison

```gleam
pub type SampleComparison {
  SampleComparison(
    index: Int,
    assignment: sampling_types.Assignment,
    expected_value: Float,
    candidate_value: Float,
    comparison: sampling_types.ComparisonResult,
    source: sampling_types.SampleSource,
  )
}
```

For privacy and future production telemetry, raw assignments should not be logged by default. But they are extremely useful in developer prototype output.

### 12.4 Candidate runtime failure

```gleam
pub type CandidateRuntimeFailure {
  CandidateRuntimeFailure(
    index: Int,
    assignment: sampling_types.Assignment,
    error: sampling_types.RuntimeMathError,
  )
}
```

### 12.5 Expression debug

```gleam
pub type ExpressionDebug {
  ExpressionDebug(
    parsed_debug: String,
    normalized_debug: String,
    variables: List(String),
  )
}
```

This is intended for prototype and golden tests, not necessarily production UI.

## 13. Core Algorithm

### 13.1 Raw-string API algorithm

```text
check_algebraic_equivalence(expected_string, candidate_string, config):
  expected_parsed = parse(expected_string)
  if expected parse fails:
    return ExpectedParseFailed

  candidate_parsed = parse(candidate_string)
  if candidate parse fails:
    return CandidateParseFailed

  expected_normalized = normalize(expected_parsed)
  candidate_normalized = normalize(candidate_parsed)

  expected_vars = collect_variables(expected_normalized)
  candidate_vars = collect_variables(candidate_normalized)

  allowed_vars = resolve_allowed_variables(config.allowed_variables, expected_vars)

  validation_errors = validate candidate_vars subset allowed_vars
                    + validate expected_vars subset allowed_vars
                    + validate functions if configured
                    + validate domains for sampled variables

  if validation_errors not empty:
    return ValidationFailed

  variables_to_sample = stable sorted union(expected_vars, candidate_vars, allowed_vars needed by domains)

  if variables_to_sample is empty:
    return compare_constant_expressions(expected_normalized, candidate_normalized, config)

  return compare_over_samples(expected_normalized, candidate_normalized, variables_to_sample, config)
```

### 13.2 Sampling comparison algorithm

```text
compare_over_samples(expected, candidate, variables, config):
  attempts = 0
  valid_comparisons = []
  rejected_samples = []

  candidate_assignments = deterministic assignment stream from sampler

  while valid_comparisons.length < config.sampling.desired_count
        and attempts < config.sampling.max_attempts:

    assignment = next candidate assignment
    attempts += 1

    expected_result = evaluate(expected, assignment, config.eval)

    if expected_result is runtime error:
      record rejection for expected runtime error
      continue

    candidate_result = evaluate(candidate, assignment, config.eval)

    if candidate_result is runtime error:
      return NotEquivalent(CandidateUndefined(...))

    comparison = compare_numbers(expected_result, candidate_result, config.tolerance)

    if comparison fails:
      return NotEquivalent(ValueMismatch(...))

    append successful comparison

  if valid_comparisons.length < desired_count:
    return InsufficientValidSamples(...)

  return Equivalent(valid_comparisons.length)
```

### 13.3 Why fail on candidate runtime errors?

If the expected expression is defined at a sample point but the candidate is undefined, the candidate does not behave the same over the intended domain.

Example:

```text
expected: x
candidate: 1 / x
sample: x = 0
```

Expected is defined. Candidate is not. That is not equivalent.

### 13.4 Why retry on expected runtime errors?

If the expected expression is undefined at a generated sample point, that point is not useful for checking value equivalence over the expected expression's domain.

Example:

```text
expected: 1 / x
candidate: x^-1
sample: x = 0
```

Retry rather than fail.

## 14. Handling Normalization

The equivalence feature should use normalized expressions, but it should not require normalization to prove equivalence.

Normalization gives cheap wins:

```text
x + 2       and 2 + x
x * 2       and 2x
(x + y) + z and x + (y + z)
```

Sampling gives broader wins:

```text
2(x + 3)       and 2x + 6
(x + 1)(x - 1) and x^2 - 1
sin(x)^2 + cos(x)^2 and 1
```

Do not add expansion, factoring, cancellation, or trigonometric rewrite logic just to make the equivalence feature pass examples. If sampling can handle them, let sampling handle them.

The equivalence feature may use normalized debug strings and normalized hashes in diagnostics, but correctness should come from sample evaluation and tolerance comparison.

## 15. Variable Selection Policy

Variable selection is surprisingly important.

### 15.1 Default inferred variables

Default behavior:

```text
allowed variables = variables found in expected expression
```

This is author-friendly.

If an author writes expected answer:

```text
2x + 6
```

then a candidate using `z` should fail as an unexpected variable unless the author explicitly allowed `z`.

### 15.2 Explicit allowed variables

Explicit allowed variables should support cases where a candidate introduces canceling variables:

```text
expected: x
candidate: x + y - y
allowed variables: [x, y]
```

This can pass if sampled correctly.

### 15.3 Variables to sample

The sampler should sample the stable sorted union of variables that appear in either expression, after validation.

Example:

```text
expected vars: [x]
candidate vars: [x, y]
allowed vars: [x, y]
variables to sample: [x, y]
```

Do not sample allowed variables that do not appear anywhere unless the domain model or future config explicitly requires it.

### 15.4 Multi-variable anti-correlation

The sampler should continue to avoid correlated multi-variable assignments.

This matters because:

```text
expected: x + y
candidate: 2x
```

will pass whenever `x = y`, so correlated sample assignments can hide errors.

## 16. Domain And Sampling Defaults

Default behavior should reuse the sampling layer's defaults:

```text
range: [-10, 10]
seed: 42 or existing default
sample count: 8
max attempts: 64 or 100
include special points: true
tolerance: default expression tolerance
```

### 16.1 Special points

The equivalence sampler should include special points because they catch common edge cases:

```text
-2, -1, -0.5, 0, 0.5, 1, 2
```

These are especially useful for catching mistakes like:

```text
x^2 vs x
x/x vs 1
1/x vs x
```

Special points must still obey domain constraints and runtime validity checks.

### 16.2 Retry behavior

When expected evaluation fails at a point, retry.

When candidate evaluation fails at an expected-valid point, fail.

When generated assignments violate domain config, reject before evaluation.

When the sampler cannot produce enough valid expected-evaluation points, return `InsufficientValidSamples`.

## 17. Tolerance Policy

The equivalence feature should not invent tolerance semantics. It should reuse the sampling layer's tolerance helper.

Default:

```text
AbsoluteOrRelativeTolerance(abs: 0.0001, rel: 0.0001, epsilon: configured epsilon)
```

The prototype UI should expose tolerance controls because developers need to see how tolerance affects results.

Suggested prototype controls:

- tolerance mode:
  - no tolerance
  - absolute
  - relative
  - absolute or relative
- absolute tolerance value
- relative tolerance value
- relative epsilon floor

Future authoring UI can simplify this. The prototype can be more detailed.

## 18. Runtime Error Handling

The equivalence feature should preserve runtime error categories from the evaluation layer.

Examples:

```text
DivisionByZero
InvalidRoot
InvalidLogarithm
UndefinedTangent
InvalidFactorial
InvalidPower
Overflow
NonFiniteResult
UnsupportedEvaluationNode
```

Important policy:

| Situation | MVP behavior |
|---|---|
| Expected invalid at sample | reject sample and retry |
| Candidate invalid while expected valid | non-equivalence |
| Both invalid | reject sample and retry |
| Too many expected-invalid samples | insufficient valid samples |
| Unsupported node in expected | insufficient/evaluation failure, depending on where detected |
| Unsupported node in candidate while expected valid | non-equivalence or unsupported evaluation outcome |

## 19. Prototype LiveView Requirements

Update the existing developer-only Math Prototype LiveView with a new section titled:

```text
Algebraic Equivalence
```

This is not production authoring UI and not student UI. It is a developer validation surface.

### 19.1 Basic UI layout

Add two text inputs:

```text
Expected expression
Candidate expression
```

Add a button:

```text
Check Equivalence
```

Suggested default values:

```text
Expected expression: 2(x + 3)
Candidate expression: 2x + 6
```

### 19.2 Required configuration UI

Include enough config controls to exercise the feature:

- Sample count
  - default: 8
- Seed
  - default: 42 or existing sampling default
- Max attempts
  - default: 64 or 100
- Include special points
  - checkbox
- Allowed variables
  - text input, comma-separated
  - allow blank value meaning infer from expected
- Domain configuration
  - MVP prototype can start simple:
    - lower bound
    - upper bound
    - inclusive/exclusive toggles
    - integer-only checkbox
    - exclusions text input, comma-separated
  - If per-variable domain rows are easy, prefer them.
  - If not, start with one shared default domain for all variables and document that limitation in the UI.
- Tolerance mode
  - no tolerance
  - absolute
  - relative
  - absolute or relative
- Absolute tolerance
- Relative tolerance
- Relative epsilon floor

Optional advanced controls:

- Allowed functions selector or text input.
- Diagnostic level selector.
- Show/hide detailed sample table.

### 19.3 Result display

After checking equivalence, display a clear result badge:

```text
Equivalent
Not equivalent
Parse error
Validation error
Insufficient valid samples
Candidate undefined at sample
```

The result display should include:

- high-level outcome;
- expected parsed/normalized debug string;
- candidate parsed/normalized debug string;
- variables detected in expected;
- variables detected in candidate;
- effective variables sampled;
- effective config summary;
- number of valid samples requested;
- number of valid samples found;
- number of rejected samples;
- first failure details if any.

### 19.4 Sample comparison table

For detailed diagnostics, show a table:

| Index | Source | Assignment | Expected value | Candidate value | Difference | Tolerance result |
|---:|---|---|---:|---:|---:|---|

Example row:

| 1 | SpecialPoint | `{x: 2}` | `10` | `10` | `0` | pass |

For a failed comparison, highlight or clearly label the first failing row.

### 19.5 Rejected sample summary

Display rejected samples in aggregate form:

| Reason | Count |
|---|---:|
| Expected DivisionByZero | 1 |
| Domain exclusion | 2 |
| Duplicate assignment | 1 |

Do not over-optimize this initially. Even simple debug text is acceptable for the first prototype, as long as it is stable and understandable.

### 19.6 Example presets

The prototype should include quick-fill examples if easy. This will make testing much faster.

Suggested examples:

| Label | Expected | Candidate | Expected result |
|---|---|---|---|
| Expansion | `2(x+3)` | `2x+6` | Equivalent |
| Near miss | `2(x+3)` | `2x+7` | Not equivalent |
| Factoring | `(x+1)(x-1)` | `x^2-1` | Equivalent |
| Sign error | `x^2-1` | `x^2+1` | Not equivalent |
| Trig identity | `sin(x)^2 + cos(x)^2` | `1` | Equivalent |
| Domain issue | `x` | `1/(1/x)` | Depends on sample/domain; should fail if `x=0` checked |
| Expected domain | `1/x` | `x^-1` | Equivalent over expected-defined samples |
| Unexpected variable | `x+1` | `x+y` | Validation error if allowed vars inferred |

### 19.7 UX guidance

The prototype should be honest about what is happening. Include a small note:

```text
This checks equivalence by deterministic sampling over the configured domain. It is not symbolic proof.
```

That one sentence will prevent confusion.

## 20. Elixir / LiveView Integration Notes

The prototype LiveView likely needs a thin bridge from Elixir to the shared Gleam API.

Implementation direction:

- Keep parsing/equivalence behavior in Gleam.
- Keep LiveView as a form + renderer.
- Do not duplicate equivalence logic in Elixir.
- Convert UI form values into `AlgebraicEquivalenceConfig`.
- Call the public `torus_math` equivalence function.
- Convert the structured result into display data.

For the prototype, it is acceptable to render stable debug strings directly. For production, a more curated display should be built later.

## 21. Testing Strategy

### 21.1 Unit tests

Add focused tests for the equivalence module:

- equivalent simple arithmetic;
- equivalent commutative/associative forms;
- expansion/factoring examples;
- powers;
- functions;
- constants;
- multi-variable expressions;
- candidate value mismatch;
- candidate runtime failure;
- expected runtime rejection and retry;
- insufficient valid samples;
- unexpected variables;
- constant expression comparison;
- tolerance pass/fail boundaries.

### 21.2 Golden corpus

Create a golden corpus that can be reused by future grading and author-preview work.

Recommended categories:

#### Basic equivalent expressions

```text
2(x+3) == 2x+6
x+2 == 2+x
x*y == y*x
(x+y)+z == x+(y+z)
```

#### Factoring/expansion

```text
(x+1)(x-1) == x^2-1
(x+2)^2 == x^2 + 4x + 4
```

#### Constants and functions

```text
sqrt(2)/2 == 1/sqrt(2)
sin(x)^2 + cos(x)^2 == 1
exp(ln(x)) == x over x > 0
log10(100) == 2
```

#### Near misses

```text
2(x+3) != 2x+7
x^2 != x
x+y != 2x
x^2-1 != x^2+1
```

#### Validation failures

```text
expected: x+1, candidate: x+y, allowed inferred from expected -> unexpected y
unsupported function if any exists in config
```

#### Domain-sensitive examples

```text
1/x == x^-1 over expected-defined domain
x == 1/(1/x) should fail if x=0 is a valid expected sample
ln(x) == log(x) over x > 0
sqrt(x)^2 == x over x >= 0
```

#### Insufficient sample examples

```text
expected: 1/x
domain: x in [0, 0]
result: insufficient valid samples
```

### 21.3 Cross-target tests

Required gates:

```sh
cd gleam && gleam format --check src test
cd gleam && gleam test --target erlang
cd gleam && gleam test --target javascript
```

Equivalence outcomes, debug strings, sample details, and tolerance results should be stable across both targets.

### 21.4 Prototype tests

If the prototype LiveView already has tests, add lightweight coverage that:

- renders the equivalence panel;
- submits two equivalent expressions;
- displays `Equivalent`;
- submits a near miss;
- displays `Not equivalent`;
- submits a parse error;
- displays parse-error diagnostics.

Do not over-invest in full UI test coverage for developer-only prototype UI.

## 22. Acceptance Criteria

### AC-001: raw-string equivalence API

A public API exists that accepts expected string, candidate string, and equivalence config, and returns a structured equivalence result.

### AC-002: normalized-expression equivalence API

A lower-level API exists that accepts normalized expected and candidate expressions and returns the same result taxonomy.

### AC-003: equivalent expressions pass

The following pass under default config:

```text
2(x+3) vs 2x+6
(x+1)(x-1) vs x^2-1
```

### AC-004: near misses fail

The following fail under default config:

```text
2(x+3) vs 2x+7
x^2 vs x
```

### AC-005: syntax failures are distinct

Expected parse failures and candidate parse failures return distinct outcomes.

### AC-006: validation failures are distinct

Unexpected variables return validation failure, not non-equivalence.

### AC-007: candidate runtime failures are distinct

If expected is defined at a sample point but candidate is not, return a candidate runtime failure / non-equivalence outcome.

### AC-008: expected runtime failures retry

If expected is undefined at a generated sample point, the system retries until enough valid samples are found or max attempts is exhausted.

### AC-009: insufficient valid samples are explicit

If enough valid expected-defined samples cannot be found, return `InsufficientValidSamples` with diagnostic details.

### AC-010: tolerance is reused

All numeric comparisons use the existing sampling layer's tolerance helper.

### AC-011: deterministic cross-target behavior

Equivalence results are deterministic and match under Erlang and JavaScript Gleam tests for the golden corpus.

### AC-012: prototype UI exists

The Math Prototype LiveView includes an Algebraic Equivalence panel with two expression inputs, a check button, core config controls, and structured result output.

### AC-013: no production grading integration

This work does not change production Short Answer, Multi-Input, Number, or legacy Math grading behavior.

## 23. Performance Posture

Equivalence cost is roughly:

```text
parse expected + parse candidate
+ normalize expected + normalize candidate
+ up to max_attempts * two expression evaluations
+ tolerance comparisons
```

For typical expressions and sample counts around 8, this should be inexpensive.

Performance guidelines:

- Avoid string formatting inside the hot loop unless diagnostics require it.
- Stop early on first value mismatch.
- Stop early on candidate runtime failure at an expected-valid point.
- Bound work by `max_attempts`.
- Keep sample count as an advanced setting.
- Add representative performance fixtures, but do not set production latency budgets in this phase.

## 24. Observability And Privacy

No production telemetry is required in this phase.

If debug or telemetry hooks are added later, prefer:

- outcome category;
- sample count;
- attempt count;
- rejection category counts;
- normalized expression hash;
- elapsed time bucket.

Avoid raw expressions and raw assignments in production telemetry by default.

Prototype UI may display raw expressions and assignments because it is developer-only.

## 25. Backward Compatibility

This feature should not change existing behavior for:

- Number inputs;
- Short Text inputs;
- Paragraph inputs;
- Dropdown inputs;
- legacy Math exact-LaTeX input;
- existing response-rule evaluation;
- adaptive activity evaluation.

No database migration is required.

No activity JSON schema change is required for this phase unless a prototype-only config object is stored locally in UI state.

## 26. Risks And Mitigations

### Risk: false positives from sampling

Sampling can accept a wrong expression if the sampled points are unlucky.

Mitigations:

- use special points plus pseudo-random points;
- default to at least 8 valid samples;
- avoid correlated multi-variable samples;
- add strong golden tests;
- be transparent that this is sampling-based equivalence, not symbolic proof.

### Risk: hidden domain mismatch

Expressions may match on sampled points but differ at rare undefined points.

Mitigations:

- document MVP domain policy clearly;
- include special points like `0`, `1`, and `-1`;
- preserve candidate runtime failures;
- add future strict-domain mode if needed.

### Risk: floating-point differences

Trigonometric, logarithmic, exponential, and radical expressions may produce tiny numeric differences.

Mitigations:

- reuse absolute/relative tolerance;
- validate non-finite results;
- write tests around tolerance boundaries;
- avoid exact float equality for sampled expression equivalence.

### Risk: prototype UI becomes production UI by accident

The equivalence panel may expose too many internals for authors or students.

Mitigations:

- clearly label it developer-only;
- keep it in the existing Math Prototype LiveView;
- do not wire it into production activity authoring or delivery.

### Risk: scope creep into CAS behavior

It will be tempting to add symbolic rewrites when a test fails.

Mitigations:

- keep equivalence sampling-based;
- do not add expansion/factoring/cancellation in this phase;
- create future named work items for polynomial normal form or rational normal form if needed.

## 27. Open Questions

1. Should default allowed variables infer only from the expected expression, or should the candidate be allowed to introduce canceling variables by default?
   - Recommendation: infer from expected only.

2. What exact default seed should be used?
   - Recommendation: reuse the sampling layer's default if one exists; otherwise use `42`.

3. What exact default sample count should be used?
   - Recommendation: 8 valid samples.

4. Should strict domain compatibility be added now?
   - Recommendation: no. Add only `ExpectedDefinedDomain` for MVP.

5. Should the prototype UI support per-variable domain rows immediately?
   - Recommendation: yes if straightforward; otherwise start with a shared domain plus exclusions and add rows later.

6. Should result details include all successful sample comparisons or only first failure plus summary?
   - Recommendation: detailed results in prototype/tests; summary-friendly result shape for future production.

## 28. Future Work

After this feature, likely next steps are:

- Exact form and representation constraints.
- Unit syntax and unit-aware evaluation.
- Feedback rules and partial credit.
- Author preview integration.
- Production activity evaluation integration.
- Authoring UI for Math Expression configuration.
- Optional strict-domain compatibility mode.
- Optional polynomial-normal-form or rational-normal-form equivalence enhancements.

## 29. Implementation Checklist

- [ ] Define algebraic equivalence config and result types.
- [ ] Add raw-string equivalence API through `torus_math.gleam`.
- [ ] Add normalized-expression equivalence API.
- [ ] Implement parse/normalize/validate pipeline helpers.
- [ ] Resolve allowed variables and variables-to-sample policy.
- [ ] Implement expected-defined-domain sampling comparison loop.
- [ ] Reuse sampling layer tolerance helper.
- [ ] Add stable debug formatting.
- [ ] Add golden corpus tests.
- [ ] Add cross-target tests.
- [ ] Update Math Prototype LiveView with Algebraic Equivalence panel.
- [ ] Add prototype examples/presets if practical.
- [ ] Confirm no production grading behavior changed.

## 30. Summary

This feature should make Torus's math system feel real: it is the point where `2x + 6` can be accepted for `2(x + 3)`.

The correct architecture is not to build a symbolic algebra engine. The correct architecture is to compose the work already completed:

```text
parser
  -> normalization
  -> deterministic sampling
  -> numeric evaluation
  -> tolerance comparison
  -> structured equivalence result
```

The MVP should be deterministic, bounded, testable, transparent, and honest about sampling limitations. It should produce strong developer diagnostics through the Math Prototype LiveView while avoiding production grading or authoring UI changes until the equivalence behavior is stable.
