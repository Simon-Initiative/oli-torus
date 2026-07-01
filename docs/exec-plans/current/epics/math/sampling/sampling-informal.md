# Deterministic Expression Evaluation And Sampling Infrastructure

## Informal Product Requirements And Technical Design

## Purpose

This document describes the next major feature layer for the Torus Math Evaluation work after the native Gleam parser and normalization layers are complete.

The goal of this feature is **not** to determine full algebraic equivalence yet. The goal is to build the independent, deterministic primitives that algebraic equivalence will depend on:

1. A pure numeric evaluator.
2. A variable assignment model.
3. A variable domain model.
4. A deterministic seeded sampler.
5. A sampling executor that can find valid points for an expression.
6. A numeric comparison helper for absolute and relative tolerance.

This feature should be treated as the bridge between:

```text
parsed / normalized expression
```

and:

```text
future algebraic equivalence by repeated deterministic evaluation
```

The central product claim is:

> Given a parsed or normalized expression and a concrete assignment of variable values, Torus can deterministically evaluate the expression to a finite numeric value or return a structured runtime math error. Given a domain configuration and a deterministic seed, Torus can generate repeatable sample assignments suitable for later equivalence testing.

## Placement In The Roadmap

This feature comes after parser and normalization work and before algebraic expression equivalence.

The parser proved that Torus can turn ASCII math into a stable AST. Normalization proved that Torus can convert equivalent structural forms into a more stable internal representation without trying to act as a full symbolic algebra system.

This feature answers the next question:

> Can Torus reliably compute the value of an expression at specific variable values, and can it generate those variable values deterministically?

Only after that is true should Torus attempt this later question:

> Are the author's expected expression and the student's expression equivalent over a configured domain?

## Strong Product Stance

This feature should be built very deliberately and narrowly.

Torus should **not** start by implementing `equivalent(expected, candidate)`.

Instead, Torus should first implement:

```text
evaluate(expression, assignment) -> value or runtime error
```

then:

```text
sample(domain_config, seed) -> deterministic assignments
```

then:

```text
evaluate_many(expression, assignments) -> values or runtime errors
```

and only later:

```text
equivalent(expected, candidate, config) -> equivalence result
```

This sequencing matters because equivalence is not a primitive operation. Equivalence is a policy layered over repeated deterministic evaluations.

## Why Sampling Exists

The long-term goal of Math Expression grading is to accept mathematically equivalent student answers without requiring exact strings.

For example, if the author enters:

```text
2(x + 3)
```

then the student should be allowed to enter:

```text
2x + 6
```

A symbolic algebra system might prove these are equivalent by expanding, simplifying, and comparing canonical forms. But building a full symbolic algebra system is expensive, risky, and likely unnecessary for the first production version of Torus Math Expression grading.

Sampling provides a practical middle path.

Instead of proving symbolically that:

```text
2(x + 3) ≡ 2x + 6
```

Torus can evaluate both expressions at multiple values of `x`:

| x | `2(x + 3)` | `2x + 6` |
|---:|---:|---:|
| -2 | 2 | 2 |
| 0 | 6 | 6 |
| 1 | 8 | 8 |
| 4 | 14 | 14 |

If the expressions match across a carefully chosen deterministic sample set, Torus has strong practical evidence that they are equivalent.

Sampling is essentially **behavioral equivalence testing**:

> Do these two expressions produce the same output for the same input values?

This is similar in spirit to property-based testing. It is not the same as symbolic proof.

## What Sampling Is Not

Sampling is not simplification.

Sampling is not normalization.

Sampling is not a full computer algebra system.

Sampling is not a universal proof technique for every possible mathematical expression.

Sampling is a deterministic, bounded, testable way to compare expression behavior over configured domains.

The evaluator and sampler should be humble about their role. They should produce structured facts that later layers can use. They should not hide ambiguity behind a simple boolean too early.

## Why Determinism Is Mandatory

Torus grading must be deterministic.

This must never happen:

```text
Student submits answer.
Random samples happen to pass.
Student submits the same answer again.
Different random samples fail.
```

That would be unacceptable for assessment.

Therefore, sampling must use a deterministic pseudo-random generator implemented in Gleam. It must not use runtime random functions from JavaScript, Erlang, or Elixir.

Given the same:

```text
expression
variable domain config
sample count
seed
runtime options
```

Torus must generate the same assignments and the same evaluation outcomes every time.

This is necessary for:

- grading consistency
- author preview
- debugging
- automated tests
- reproducible error reports
- browser/server parity
- auditability

In this system, “random” really means:

> pseudo-random, seeded, deterministic, portable, and repeatable.

## Non-Goals

This feature should intentionally avoid the following:

### No algebraic equivalence decision yet

Do not build the final `expected` versus `candidate` equivalence API in this feature. This feature should make that later API easy, but it should not combine all concerns prematurely.

### No symbolic simplification

Do not expand, factor, cancel, collect terms, apply identities, or choose “simpler” forms.

Those belong to normalization or later named algebraic transformation passes, not this feature.

### No unit evaluation yet

Units should remain a later layer. This feature evaluates real-valued expressions only.

For example:

```text
9.8 m/s^2
```

is not part of this feature unless the unit parser has already split it into:

```text
value expression: 9.8
unit expression: m/s^2
```

Even then, this feature should only evaluate the value expression.

### No complex numbers

The MVP evaluator should be real-valued only.

Expressions that require complex numbers should produce structured runtime errors.

Examples:

```text
sqrt(-1)
(-1)^(1/2)
ln(-2)
```

### No broad domain inference

Do not try to infer all domains from expression structure yet.

It is reasonable to detect runtime domain errors during evaluation, such as division by zero or invalid logarithm. It is not reasonable in this feature to fully infer symbolic domains like:

```text
ln(x - 2) requires x > 2
```

Domain inference may become a later feature. For now, domains should primarily come from author configuration plus runtime validity checks.

### No raw learner telemetry by default

This feature should expose structured diagnostic data, but production telemetry should avoid logging raw learner expressions by default. Hashes, categories, timings, and aggregate outcomes are safer than raw expression strings.

## Intended Users And Use Cases

### Developers

Developers need a clean, deterministic layer that can be tested independently from activity scoring and authoring UI.

They should be able to write tests like:

```text
evaluate("sqrt(x)", {x: 4}) -> 2

evaluate("sqrt(x)", {x: -1}) -> InvalidRoot

sample(x in [-10, 10], seed 42, count 8) -> same assignments on BEAM and JavaScript
```

### Authors

Authors will eventually use this indirectly through preview.

For example, an author should be able to preview an expression and see that sample values are valid or that a domain configuration is problematic.

If the author expects:

```text
1 / x
```

but configures a domain that only samples `x = 0`, the system should be able to report:

```text
Could not find enough valid sample points. The expression is undefined for the sampled values. Consider excluding 0 or changing the variable domain.
```

### Students

Students should not see low-level sample details.

Students should see actionable messages only when needed:

```text
This expression is undefined for some required values.
```

or:

```text
Check your expression; it divides by zero.
```

Detailed sample assignments should be reserved for developer tooling and author preview.

## Theory Of Operation

The feature has three major pieces:

```text
Expression evaluator
Domain-aware sampler
Numeric comparator
```

The evaluator answers:

```text
What is the numeric value of this expression for this variable assignment?
```

The sampler answers:

```text
Which variable assignments should we use for testing?
```

The comparator answers:

```text
Are these two numeric results close enough under the configured tolerance?
```

Together, they will later support algebraic equivalence:

```text
For each sampled assignment:
  evaluate expected expression
  evaluate candidate expression
  compare results with tolerance
```

But for this feature, each component should be implemented and tested independently.

## Opinionated MVP Decisions

### Decision 1: Evaluate over real numbers only

The evaluator should operate over real `Float` values for this phase.

Complex values are out of scope.

If an expression requires a complex result, return a runtime math error.

Examples:

```text
sqrt(-1)      -> InvalidRoot
ln(-1)        -> InvalidLogarithm
(-2)^(0.5)    -> InvalidPower
```

### Decision 2: Trigonometric functions use radians

All trigonometric functions should use radians.

```text
sin(pi / 2) -> 1
```

Do not support degree mode in this feature.

If degree mode is ever needed, it should be an explicit author/evaluator configuration, not an implicit interpretation.

### Decision 3: `log(x)` means natural log

The syntax requirements already distinguish:

```text
log(x)
log10(x)
log2(x)
ln(x)
```

For consistency with the existing plan:

```text
log(x)  -> natural log
ln(x)   -> natural log
log10(x)-> base 10
log2(x) -> base 2
```

### Decision 4: Use structured runtime errors, not exceptions or booleans

The evaluator should not return only `true`, `false`, or `Nil`.

It should return:

```text
Result(Float, RuntimeMathError)
```

or a richer equivalent.

The error should identify what failed and where practical.

Examples:

```text
DivisionByZero
MissingVariable("x")
InvalidLogarithm
InvalidRoot
InvalidFactorial
InvalidPower
UndefinedTangent
NonFiniteResult
```

### Decision 5: Expected-expression invalid samples are retried

When sampling for future equivalence, if a sampled assignment makes the expected expression undefined, the sample point should usually be considered invalid and retried.

Example:

```text
expected: 1 / x
sample: x = 0
```

This should not immediately mark a student wrong. It means the sampler selected a bad point for that expected expression.

### Decision 6: Candidate-expression invalidity at an expected-valid sample is evidence of failure

In the future equivalence layer, if the expected expression is valid at a sample point but the candidate expression is invalid, that is not a retry. That is a meaningful mismatch.

Example:

```text
expected: x
candidate: 1 / x
sample: x = 0
```

The expected expression evaluates to `0`. The candidate expression is undefined. That should be treated as a candidate failure unless the configured domain excludes `0`.

### Decision 7: Sampling should use special points plus seeded pseudo-random points

Do not use only random-looking values.

Do not use only special values like `0`, `1`, and `-1`.

Use both.

Special points catch common edge cases. Seeded pseudo-random points reduce the chance of accidental matches.

### Decision 8: The sampler must avoid correlated multi-variable assignments

For expressions with multiple variables, do not repeatedly assign all variables the same value.

Bad:

```text
{x: 2, y: 2}
{x: 3, y: 3}
```

This can hide incorrect answers.

Example:

```text
expected: x + y
candidate: 2x
```

If `x = y`, these match. If `x` and `y` are sampled independently, they usually do not.

### Decision 9: Insufficient valid samples is a configuration/evaluator outcome, not a student failure

If the sampler cannot find enough valid assignments for the expected expression, return a structured outcome:

```text
InsufficientValidSamples
```

This should be treated as an authoring/configuration problem, especially in preview and linting.

It should not silently become “student answer incorrect.”

### Decision 10: Preserve browser/server parity as a release requirement

The same Gleam code should run on BEAM and JavaScript targets.

The same tests should pass under both targets.

This is not optional. It is one of the core reasons for using Gleam for the math engine.

## Functional Requirements

## FR-SAMP-001: Evaluate numeric literals

The evaluator must evaluate integer, decimal, and scientific-notation numeric literals.

Examples:

```text
2        -> 2.0
2.5      -> 2.5
1.2e-3   -> 0.0012
```

The evaluator may use metadata from parsed numeric literals, but the evaluation result for this feature is a finite real number.

## FR-SAMP-002: Evaluate constants

The evaluator must support:

```text
pi
e
```

Expected behavior:

```text
pi -> mathematical pi approximation
e  -> Euler's number approximation
```

These are floating-point approximations.

## FR-SAMP-003: Evaluate variables from assignment map

The evaluator must evaluate variables using a concrete assignment.

Example:

```text
expression: 2x + y
assignment: {x: 3, y: 4}
result: 10
```

If a variable is missing, return a structured error:

```text
MissingVariable("x")
```

## FR-SAMP-004: Evaluate arithmetic operators

The evaluator must support:

```text
+
-
*
/
^
```

This includes both explicit and implicit multiplication after parsing/normalization.

Division by zero must return a structured error.

## FR-SAMP-005: Evaluate unary operators

The evaluator must support unary positive and unary negative.

Examples:

```text
-x
+x
-(x + 1)
```

## FR-SAMP-006: Evaluate supported functions

The evaluator must support:

```text
sin(x)
cos(x)
tan(x)
ln(x)
log(x)
log10(x)
log2(x)
sqrt(x)
abs(x)
exp(x)
```

All functions must return structured runtime errors for invalid real-valued inputs.

## FR-SAMP-007: Evaluate absolute value

The evaluator must support absolute value forms parsed by the parser, whether represented as:

```text
abs(x)
```

or:

```text
|x|
```

depending on the AST shape.

## FR-SAMP-008: Evaluate factorial where valid

The evaluator must support factorial for non-negative integers within a safe bound.

Recommended MVP behavior:

```text
0! -> 1
1! -> 1
5! -> 120
```

Invalid:

```text
(-1)!  -> InvalidFactorial
2.5!   -> InvalidFactorial
171!   -> FactorialTooLarge or NonFiniteResult
```

Opinionated recommendation:

> Use a hard maximum factorial input of `170` if evaluating through floating-point doubles, because `171!` exceeds finite double range. A lower product cap is acceptable if the team wants more conservative behavior.

## FR-SAMP-009: Detect non-finite results

The evaluator must reject results that become:

```text
NaN
Infinity
-Infinity
```

These should be returned as structured errors, not as successful numeric values.

## FR-SAMP-010: Provide a variable assignment model

The feature must define a first-class assignment model.

Conceptually:

```text
{x: 2.5, y: -1}
```

This should be represented in Gleam with Torus-owned types, not loose maps passed around everywhere without validation.

The assignment model should be serializable for debugging and preview.

## FR-SAMP-011: Provide a variable domain model

The feature must define a first-class domain model for variables.

At minimum, each variable domain should support:

- lower bound
- upper bound
- inclusive/exclusive bounds
- exclusions
- integer-only sampling
- optional preferred/special values

Example:

```text
x ∈ [-5, 5], exclude 0
n ∈ [1, 10], integers only
```

## FR-SAMP-012: Provide default domains

If an author does not specify a domain, the sampler needs a default effective sampling range.

Opinionated recommendation:

```text
real-valued variables: [-10, 10]
integer-only variables: [-10, 10]
```

Do not allow truly unbounded sampling in the MVP. If the semantic domain is unbounded, the sampler should still use a finite effective range.

## FR-SAMP-013: Generate deterministic sample assignments

The sampler must generate deterministic assignments from:

```text
variables
domain config
sample count
seed
```

The same input must produce the same output on both BEAM and JavaScript.

## FR-SAMP-014: Use a portable seeded pseudo-random generator

The PRNG must be implemented in pure Gleam.

Do not use JavaScript `Math.random`, Erlang random functions, Elixir random functions, or any target-specific random source.

Opinionated recommendation:

Use a small deterministic integer PRNG such as a Park-Miller minimal standard generator:

```text
modulus = 2147483647
multiplier = 48271
state = state * multiplier mod modulus
u = state / modulus
```

This is not cryptographic and does not need to be. It only needs to be deterministic, portable, and good enough for sample selection.

## FR-SAMP-015: Include special points

The sampler should include special points before or alongside pseudo-random values.

Recommended special values:

```text
0
1
-1
2
-2
0.5
-0.5
3
-3
```

These should be filtered through the variable domain.

For bounded domains, special points outside the domain should be ignored or adapted.

## FR-SAMP-016: Avoid correlated multi-variable sampling

For multiple variables, generated assignments should avoid assigning every variable the same value by default.

A deterministic offset strategy is acceptable.

Example for variables `[x, y]`:

```text
sample 1: x = 0,  y = 1
sample 2: x = 1,  y = -1
sample 3: x = -1, y = 2
```

Pseudo-random samples should draw each variable independently from the PRNG stream.

## FR-SAMP-017: Provide sampling retry behavior

The sampling executor must be able to retry when generated assignments are invalid for the expression being sampled.

Example:

```text
expression: 1 / x
sampled assignment: {x: 0}
```

The executor should reject that sample and try another assignment, up to a configured maximum attempt count.

Recommended defaults:

```text
desired valid samples: 8
max attempts: 50 or 100
```

## FR-SAMP-018: Return insufficient sample diagnostics

If the executor cannot find enough valid samples, it must return a structured result with diagnostics.

Example:

```text
InsufficientValidSamples(
  requested: 8,
  found: 3,
  attempts: 50,
  invalid_reason_summary: [DivisionByZero: 47]
)
```

This should support author preview and linting.

## FR-SAMP-019: Provide numeric tolerance comparison

The feature must provide a helper for comparing two numeric values with tolerance.

At minimum:

- no tolerance
- absolute tolerance
- relative tolerance
- absolute-or-relative tolerance

Recommended comparison:

```text
diff = abs(actual - expected)
absolute_pass = diff <= abs_tolerance
relative_pass = diff <= rel_tolerance * max(abs(expected), epsilon)
pass = absolute_pass OR relative_pass
```

## FR-SAMP-020: Provide structured comparison details

The comparison helper should return details, not just pass/fail.

Example:

```text
ComparisonResult(
  passed: False,
  expected: 100.0,
  actual: 101.2,
  difference: 1.2,
  absolute_passed: False,
  relative_passed: False
)
```

These details are useful for tests, author preview, and future feedback.

## FR-SAMP-021: Provide cross-target tests

All core evaluator, sampler, and comparison tests must pass under both:

```text
gleam test --target erlang
gleam test --target javascript
```

Browser/server parity is an acceptance requirement.

## FR-SAMP-022: Provide performance checks

This feature should include performance checks on representative expression corpora.

The point is not to prematurely optimize. The point is to detect obvious regressions before this code becomes part of grading.

Suggested benchmark cases:

- simple arithmetic
- polynomial expressions
- expressions with functions
- expressions with multiple variables
- expressions that trigger retries
- expressions with domain errors

## Proposed Module Layout

The exact layout may vary, but this feature should stay under the existing Gleam math namespace.

Recommended modules:

```text
gleam/src/math/eval.gleam
gleam/src/math/eval/types.gleam
gleam/src/math/domain.gleam
gleam/src/math/assignment.gleam
gleam/src/math/sample.gleam
gleam/src/math/sample/prng.gleam
gleam/src/math/tolerance.gleam
gleam/src/math/runtime_error.gleam
```

Tests:

```text
gleam/test/math_eval_test.gleam
gleam/test/math_domain_test.gleam
gleam/test/math_sampler_test.gleam
gleam/test/math_tolerance_test.gleam
gleam/test/math_cross_target_fixtures_test.gleam
```

Keep public API small. Internal modules can change. Public modules should be stable enough for Elixir and browser adapters.

## Suggested Public API

The core API should be intentionally narrow.

Conceptual shape:

```gleam
pub fn evaluate(
  expression: NormalExpr,
  assignment: Assignment,
  config: EvalConfig,
) -> Result(Float, RuntimeMathError)
```

```gleam
pub fn sample_assignments(
  variables: List(String),
  domains: DomainConfig,
  config: SamplingConfig,
) -> SampleBatch
```

```gleam
pub fn valid_samples_for_expression(
  expression: NormalExpr,
  variables: List(String),
  domains: DomainConfig,
  config: SamplingConfig,
) -> Result(ValidSampleBatch, SamplingError)
```

```gleam
pub fn compare_numbers(
  expected: Float,
  actual: Float,
  tolerance: Tolerance,
) -> ComparisonResult
```

Do not expose more than necessary at first.

## Suggested Type Design

The following types are illustrative, not final Gleam syntax requirements.

### Evaluation config

```gleam
pub type EvalConfig {
  EvalConfig(
    angle_mode: AngleMode,
    zero_policy: ZeroPolicy,
    factorial_max: Int,
    tangent_epsilon: Float,
    non_finite_policy: NonFinitePolicy,
  )
}

pub type AngleMode {
  Radians
}
```

Opinionated recommendation:

Only support `Radians` in MVP. The type leaves room for later `Degrees`, but do not implement it now.

### Assignment

```gleam
pub type Assignment {
  Assignment(values: List(VariableValue))
}

pub type VariableValue {
  VariableValue(name: String, value: Float)
}
```

A list may be easier to keep portable and deterministic than exposing map ordering assumptions. Internally, lookup can be optimized later if needed.

### Runtime errors

```gleam
pub type RuntimeMathError {
  MissingVariable(name: String)
  DivisionByZero
  InvalidRoot(value: Float)
  InvalidLogarithm(value: Float)
  UndefinedTangent(value: Float)
  InvalidFactorial(value: Float)
  FactorialTooLarge(value: Int, max: Int)
  InvalidPower(base: Float, exponent: Float)
  Overflow
  NonFiniteResult
  UnsupportedEvaluationNode(description: String)
}
```

If source spans are available on normalized nodes, errors should optionally include spans.

This is valuable for preview and future student-facing feedback.

### Domain config

```gleam
pub type DomainConfig {
  DomainConfig(variables: List(VariableDomain))
}

pub type VariableDomain {
  VariableDomain(
    name: String,
    lower: Bound,
    upper: Bound,
    exclusions: List<Float>,
    integer_only: Bool,
    preferred_values: List(Float),
  )
}

pub type Bound {
  Inclusive(Float)
  Exclusive(Float)
}
```

If a variable is not listed, use the default domain.

### Sampling config

```gleam
pub type SamplingConfig {
  SamplingConfig(
    seed: Int,
    desired_count: Int,
    max_attempts: Int,
    include_special_points: Bool,
  )
}
```

Recommended defaults:

```text
seed: stable value from equality config or item config
desired_count: 8
max_attempts: 64 or 100
include_special_points: true
```

### Sample assignment

```gleam
pub type SampleAssignment {
  SampleAssignment(
    index: Int,
    assignment: Assignment,
    source: SampleSource,
  )
}

pub type SampleSource {
  SpecialPoint
  PseudoRandom
}
```

The `source` is useful for diagnostics.

### Sampling result

```gleam
pub type ValidSampleBatch {
  ValidSampleBatch(
    samples: List(SampleAssignment),
    attempts: Int,
    rejected: List(RejectedSampleSummary),
  )
}

pub type SamplingError {
  InsufficientValidSamples(
    requested: Int,
    found: Int,
    attempts: Int,
    rejected: List(RejectedSampleSummary),
  )
}
```

### Tolerance

```gleam
pub type Tolerance {
  NoTolerance
  AbsoluteTolerance(abs: Float)
  RelativeTolerance(rel: Float, epsilon: Float)
  AbsoluteOrRelativeTolerance(abs: Float, rel: Float, epsilon: Float)
}
```

Opinionated recommendation:

Use `AbsoluteOrRelativeTolerance` as the default for expression sampling once equivalence is implemented.

A reasonable initial default for internal equivalence exploration:

```text
absolute: 1e-9
relative: 1e-9
epsilon: 1e-12
```

Product may choose a more forgiving default later for student-facing grading.

### Comparison result

```gleam
pub type ComparisonResult {
  ComparisonResult(
    passed: Bool,
    expected: Float,
    actual: Float,
    difference: Float,
    absolute_passed: Bool,
    relative_passed: Bool,
  )
}
```

## Evaluation Semantics

## Numbers

Numeric literals evaluate to their parsed numeric value.

The evaluator should not discard raw numeric metadata globally, because form checks later need it. But this feature's numeric evaluation returns a `Float`.

## Variables

A variable must be present in the assignment.

If not present:

```text
MissingVariable(name)
```

This is a runtime evaluation error, not a parse error.

## Addition, subtraction, multiplication

These are straightforward real-valued operations.

After each operation, check that the result is finite.

## Division

Division by zero must produce:

```text
DivisionByZero
```

Opinionated recommendation:

Treat exactly zero as division by zero. Do not automatically treat all tiny denominators as zero in the evaluator. Instead, detect non-finite or overflow results after evaluation.

Reason:

- A tiny denominator may be mathematically valid.
- The sampler and domain config should avoid problematic values where possible.
- Over-aggressive near-zero handling can introduce surprising false errors.

## Power

Power is one of the most dangerous operators.

Recommended MVP behavior for real-valued evaluation:

```text
base > 0: allow any real exponent
base = 0 and exponent > 0: allow
base = 0 and exponent <= 0: InvalidPower or DivisionByZero
base < 0 and exponent is integer: allow
base < 0 and exponent is non-integer: InvalidPower
0^0: InvalidPower, unless the team explicitly chooses calculator semantics
```

Opinionated recommendation:

Treat `0^0` as invalid in the domain-aware evaluator.

This is stricter than some programming-language behavior, but it is safer for a grading system that cares about domains.

If product later wants calculator-style `0^0 = 1`, make that an explicit policy setting.

## Square root

```text
sqrt(x)
```

Valid only for:

```text
x >= 0
```

Invalid:

```text
x < 0 -> InvalidRoot
```

## Logarithms

```text
ln(x)
log(x)
log10(x)
log2(x)
```

Valid only for:

```text
x > 0
```

Invalid:

```text
x <= 0 -> InvalidLogarithm
```

## Trigonometric functions

```text
sin(x)
cos(x)
tan(x)
```

Use radians.

For tangent:

```text
tan(x) = sin(x) / cos(x)
```

Tangent is undefined when `cos(x)` is zero.

Because floating point is approximate, use a small threshold:

```text
abs(cos(x)) < tangent_epsilon -> UndefinedTangent
```

Recommended initial value:

```text
tangent_epsilon = 1e-12
```

## Absolute value

```text
abs(x)
```

Always valid for finite real inputs.

## Exponential

```text
exp(x)
```

Valid when the result is finite.

If it overflows:

```text
Overflow or NonFiniteResult
```

## Factorial

Factorial is valid only for non-negative integers within the configured maximum.

Recommended:

```text
0 <= n <= 170
```

Invalid:

```text
n < 0
n not integer
n > max
```

Return structured errors.

## Non-Finite Handling

Any operation that produces a non-finite value must return a runtime error.

Do not compare non-finite values.

Do not treat `NaN` as equal to anything.

Do not allow `Infinity` to pass through as a normal numeric value.

## Domain Model

A variable domain describes where the sampler is allowed to draw values.

It does not necessarily prove that the expression is defined everywhere in that domain.

For example:

```text
x ∈ [-10, 10]
expression: 1 / x
```

The domain allows `0`, but the expression is undefined there.

That is why the sampling executor still needs runtime validity checks.

## Default Domain

If no domain is configured, use:

```text
[-10, 10]
```

This is not mathematically universal. It is a practical finite sampling region.

The default domain should be documented in author-facing materials once equivalence is exposed.

## Bounds

Support inclusive and exclusive bounds:

```text
[-5, 5]
(-5, 5)
[0, 10)
```

Sampling must respect these bounds.

## Exclusions

Support explicit exclusions:

```text
exclude 0
exclude 1
```

For integer domains, exclusions are straightforward.

For real domains, exact exclusions mostly affect special points, because pseudo-random floating values are unlikely to hit exact excluded values.

That is acceptable for MVP.

## Integer-Only Domains

Integer-only domains should sample integers only.

Example:

```text
n ∈ [1, 10], integers only
```

If the range contains too few valid integers to satisfy the requested sample count, the sampler should return insufficient valid samples or reuse policy should be explicitly defined.

Opinionated recommendation:

Do not silently reuse duplicate assignments in the MVP unless the result explicitly marks duplicates. Prefer unique samples when possible.

## Sampling Strategy

The sampler should produce assignments in a deterministic sequence.

Recommended sequence:

1. Generate candidate assignments from special points.
2. Generate candidate assignments from the seeded PRNG.
3. Filter assignments through domain constraints.
4. Optionally evaluate the expression to reject runtime-invalid points.
5. Continue until desired valid sample count is reached or max attempts is exceeded.

## Special Point Strategy

Special points should include values likely to expose common mistakes:

```text
0
1
-1
2
-2
0.5
-0.5
3
-3
```

For positive-only domains, useful special values include:

```text
0.5
1
2
3
```

For integer-only domains:

```text
0
1
-1
2
-2
3
-3
```

Special points must be filtered by domain.

## Multi-Variable Special Points

For multiple variables, avoid assigning the same special point to every variable.

Use an offset.

Example:

```text
specials = [0, 1, -1, 2, -2]
variables = [x, y, z]

sample 0: x=0,  y=1,  z=-1
sample 1: x=1,  y=-1, z=2
sample 2: x=-1, y=2,  z=-2
```

This reduces accidental correlation.

## Pseudo-Random Strategy

After special points, generate pseudo-random values.

For real-valued domains:

```text
value = lower + u * (upper - lower)
```

where:

```text
u is a deterministic pseudo-random float in [0, 1)
```

For integer-only domains:

```text
value = lower_int + floor(u * count_of_valid_integer_values)
```

Then apply exclusions.

## Retry Strategy

The sampling executor should track candidate attempts.

For each candidate assignment:

1. Check domain constraints.
2. Check duplicate assignment policy.
3. Evaluate the expression.
4. If evaluation succeeds with a finite value, accept the sample.
5. If evaluation fails because the expression is undefined at that point, reject and continue.
6. If max attempts is reached before enough samples are found, return `InsufficientValidSamples`.

The rejected sample summary should count reasons.

Example:

```text
requested: 8
found: 5
attempts: 64
rejections:
  DivisionByZero: 40
  InvalidLogarithm: 19
```

## Sampling Executor Versus Future Equivalence Executor

This feature should implement a sampling executor for one expression:

```text
valid_samples_for_expression(expression, domain_config, sampling_config)
```

The future equivalence executor will use this differently:

1. Generate valid points for the expected expression.
2. Evaluate the candidate expression at those expected-valid points.
3. Treat candidate runtime errors as evidence of non-equivalence or domain mismatch.

This distinction is very important.

For this feature:

```text
expected expression invalid at sampled point -> retry
```

For future equivalence:

```text
candidate invalid at expected-valid point -> likely fail
```

## Numeric Comparison Helper

The numeric comparison helper is small but important.

It should be reusable by:

- numeric scalar evaluation
- expression sampling
- future algebraic equivalence
- author preview diagnostics

## Absolute Tolerance

Absolute tolerance compares raw difference:

```text
diff = abs(actual - expected)
pass = diff <= abs_tolerance
```

Useful near zero.

Example:

```text
expected = 0.000001
actual = 0.0000011
```

## Relative Tolerance

Relative tolerance compares scaled difference:

```text
diff = abs(actual - expected)
scale = max(abs(expected), epsilon)
pass = diff <= rel_tolerance * scale
```

Useful for large values.

Example:

```text
expected = 1,000,000
actual = 1,000,001
```

Absolute difference is `1`, but relative difference is tiny.

## Combined Tolerance

For expression sampling, the recommended default is:

```text
pass if absolute tolerance passes OR relative tolerance passes
```

This handles both near-zero and large-value comparisons.

## Tolerance Edge Cases

### Expected near zero

Relative tolerance alone behaves badly near zero.

Use an epsilon floor:

```text
scale = max(abs(expected), epsilon)
```

### Non-finite values

Do not compare non-finite values.

They should already have produced runtime errors.

### Negative tolerances

Reject negative tolerance configs at decode/validation time.

### Zero tolerance

Zero tolerance is allowed but should be treated carefully.

For floating-point expression evaluation, exact zero tolerance can be too strict for expressions involving functions like:

```text
sin(pi)
sqrt(2)^2
```

## Result Taxonomy

This feature should establish a clear taxonomy that later equivalence and feedback layers can reuse.

Recommended high-level outcomes:

```text
EvaluationSucceeded
EvaluationFailed
SamplingSucceeded
InsufficientValidSamples
ComparisonPassed
ComparisonFailed
```

Recommended runtime error categories:

```text
MissingVariable
DivisionByZero
InvalidRoot
InvalidLogarithm
UndefinedTangent
InvalidFactorial
FactorialTooLarge
InvalidPower
Overflow
NonFiniteResult
UnsupportedEvaluationNode
```

Recommended sampling error categories:

```text
NoVariablesButVariablesRequired
InvalidDomainConfig
InsufficientValidSamples
TooFewIntegerValues
AllSamplesExcluded
```

Recommended comparison failure details:

```text
DifferenceExceededTolerance
AbsoluteToleranceFailed
RelativeToleranceFailed
```

Do not collapse these into a single `false`.

## Domain And Runtime Edge Cases

## Division by zero

Expression:

```text
1 / (x - 2)
```

At:

```text
x = 2
```

Return:

```text
DivisionByZero
```

For sampling the expected expression, retry.

## Invalid logarithm

Expression:

```text
ln(x)
```

At:

```text
x <= 0
```

Return:

```text
InvalidLogarithm
```

## Invalid square root

Expression:

```text
sqrt(x)
```

At:

```text
x < 0
```

Return:

```text
InvalidRoot
```

## Undefined tangent

Expression:

```text
tan(x)
```

At values where:

```text
cos(x) ≈ 0
```

Return:

```text
UndefinedTangent
```

## Invalid factorial

Expression:

```text
x!
```

Invalid when:

```text
x < 0
x is not an integer
x is too large
```

## Invalid power

Examples:

```text
0^-1
0^0
(-1)^0.5
```

Return:

```text
InvalidPower
```

or a more specific error where useful.

## Overflow

Expression:

```text
exp(10000)
```

Return:

```text
Overflow or NonFiniteResult
```

Do not allow infinity to pass as a successful value.

## Sampling Limits And False Positives

Sampling is powerful but limited.

The system should be designed with those limits in mind.

## Sampling can miss rare differences

Example:

```text
x / x
```

and:

```text
1
```

These match for all `x != 0`, but differ in domain at `x = 0`.

If the sampler never checks `0`, it may treat them as behaviorally equivalent over sampled points.

Special points help, but they do not solve every possible rare-point issue.

## Sampling can be fooled by unlucky points

Example:

```text
expected: x^2
candidate: x
```

At:

```text
x = 0
x = 1
```

they match.

This is why sampling should not rely only on `0` and `1`.

## Multi-variable sampling can hide errors if variables are correlated

Example:

```text
expected: x + y
candidate: 2x
```

If the sampler repeatedly uses:

```text
x = y
```

the candidate can falsely pass.

The sampler must draw independent or deliberately offset values for different variables.

## Floating-point tolerance can hide tiny differences

Tolerance is necessary, but it can hide small differences.

That is acceptable for MVP if tolerance is explicit and configurable.

The evaluator should expose comparison details so authors and developers can see when an answer passed only because of tolerance.

## Periodic functions need diverse samples

Expressions involving trigonometric functions can match at many points accidentally.

Example:

```text
sin(x)
```

and:

```text
0
```

match at multiples of `pi`.

Avoid sampling only special trigonometric points unless deliberately testing them.

## High-degree polynomials may require more samples

For polynomials, if two degree-`d` polynomials agree at more than `d` distinct points, they are the same polynomial.

But Torus may not know the degree of an arbitrary parsed expression.

Default sample count should be a practical compromise, not a proof guarantee.

Recommended default:

```text
8 valid samples
```

Allow advanced configuration later.

## Testing Requirements

## Evaluator tests

Test successful evaluation:

```text
2 + 3 * 4 -> 14
2^3 -> 8
sqrt(4) -> 2
abs(-3) -> 3
sin(pi / 2) -> 1 within tolerance
log(e) -> 1 within tolerance
```

Test variable evaluation:

```text
2x + y with {x: 3, y: 4} -> 10
```

Test missing variable:

```text
x + 1 with {} -> MissingVariable("x")
```

## Runtime error tests

```text
1 / 0 -> DivisionByZero
sqrt(-1) -> InvalidRoot
ln(0) -> InvalidLogarithm
tan(pi / 2) -> UndefinedTangent, subject to epsilon
(-1)^(0.5) -> InvalidPower
(-1)! -> InvalidFactorial
2.5! -> InvalidFactorial
171! -> FactorialTooLarge or NonFiniteResult
exp(10000) -> Overflow or NonFiniteResult
```

## Domain tests

```text
x in [-5, 5]
x in (-5, 5)
x in [0, 10], exclude 0
n in [1, 10], integer_only
```

Verify that generated samples respect these domains.

## Sampler determinism tests

Given the same config:

```text
variables: [x, y]
domains: default
seed: 42
count: 8
```

The sampler must return the same assignments every time.

These tests must pass on both BEAM and JavaScript targets.

## Sampler retry tests

Expression:

```text
1 / x
```

Domain:

```text
x in [-1, 1]
```

The sampler may generate `x = 0`, reject it, and continue until enough valid samples are found.

## Insufficient sample tests

Expression:

```text
1 / x
```

Domain:

```text
x in [0, 0]
```

The sampler should return:

```text
InsufficientValidSamples
```

not crash and not produce invalid samples.

## Tolerance tests

Absolute tolerance:

```text
expected 5.0, actual 5.08, abs 0.1 -> pass
expected 5.0, actual 5.21, abs 0.1 -> fail
```

Relative tolerance:

```text
expected 100, actual 101, rel 1% -> pass
expected 100, actual 101.2, rel 1% -> fail
```

Near zero:

```text
expected 0, actual 1e-10, abs 1e-9 -> pass
```

## Multi-variable anti-correlation tests

Use a fixture that would falsely pass if `x = y` for every sample:

```text
expected: x + y
candidate-like expression for testing: 2x
```

Even though full equivalence is not implemented yet, the sampler tests should prove it generates non-correlated assignments.

## Cross-target fixture tests

Create a fixed set of expressions, domains, seeds, and expected sample assignments.

Run under:

```text
gleam test --target erlang
gleam test --target javascript
```

The output should match exactly for sample assignments and match within tolerance for evaluated floating values.

## Performance Expectations

This feature should be fast enough for author preview and grading.

Initial suggested targets:

```text
single expression evaluation: effectively instantaneous for typical ASTs
8-sample evaluation batch: comfortably below interactive preview thresholds
```

Do not overfit to a precise number yet, but start collecting timing data.

Representative corpus:

```text
2x + 6
2(x + 3)
(x + 1)(x - 1)
sqrt(x) / 2
sin(x)^2 + cos(x)^2
ln(x + 11)
1 / (x - 1)
x^2 + y^2
```

The later production roadmap mentions average evaluation latency targets. This feature should make such benchmarking possible.

## Developer Preview Expectations

The existing developer prototype UI should be extended, if practical, to show:

- expression
- assignment
- evaluation result
- runtime error, if any
- generated sample assignments
- rejected sample summary
- comparison helper result for manually entered expected/actual values

This does not need to be student-facing.

It is primarily for proving the layer and debugging domain behavior.

## Suggested Implementation Sequence

## Step 1: Define types

Create the core types for:

- evaluation config
- assignment
- runtime math errors
- domain config
- sampling config
- sample assignment
- sampling result
- tolerance
- comparison result

Do this before implementing behavior.

The type design is part of the product design.

## Step 2: Implement evaluator without sampling

Implement:

```text
evaluate(expression, assignment)
```

Support literals, constants, variables, arithmetic, powers, functions, absolute value, and factorial.

Test every runtime error.

## Step 3: Implement domain checks

Implement:

```text
assignment_satisfies_domain(assignment, domain_config)
```

Test bounds, exclusions, integer-only domains, defaults, and invalid configs.

## Step 4: Implement seeded PRNG

Implement pure Gleam PRNG.

Test exact generated sequences.

Do not proceed until BEAM and JavaScript agree.

## Step 5: Implement raw assignment sampler

Generate assignments from variables, domain config, and sampling config.

Do not evaluate expressions yet.

Test determinism and domain compliance.

## Step 6: Implement valid sample executor

Combine sampler + evaluator.

Reject runtime-invalid points.

Track rejection reasons.

Return insufficient sample diagnostics when needed.

## Step 7: Implement tolerance comparison helper

Implement no tolerance, absolute tolerance, relative tolerance, and absolute-or-relative tolerance.

Return structured details.

## Step 8: Add preview/debug formatting

Add stable debug strings for:

- assignments
- runtime errors
- sample batches
- rejected sample summaries
- comparison results

This will make the prototype UI much more useful.

## Step 9: Add performance fixtures

Add representative expression corpora and timing harnesses.

Do not block the feature on aggressive optimization. Use this mainly to establish a baseline.

## Acceptance Criteria

This feature is complete when all of the following are true:

1. A parsed or normalized expression can be evaluated at a concrete assignment.
2. Evaluation returns either a finite numeric value or a structured runtime math error.
3. The evaluator supports numbers, constants, variables, arithmetic, powers, supported functions, absolute value, and factorial.
4. Division by zero, invalid roots, invalid logarithms, undefined tangent, invalid factorial, invalid power, overflow, and non-finite results are structured errors.
5. Variable assignments are represented by a first-class Torus-owned model.
6. Variable domains support ranges, inclusive/exclusive bounds, exclusions, integer-only sampling, and defaults.
7. A pure Gleam seeded PRNG generates deterministic values on both BEAM and JavaScript.
8. The sampler generates deterministic sample assignments from variables, domains, seed, and count.
9. The sampler includes special points and pseudo-random points.
10. Multi-variable sampling avoids obvious value correlation.
11. The sampling executor can retry invalid points and report insufficient valid samples.
12. The numeric comparison helper supports absolute and relative tolerance.
13. Comparison results include diagnostic details.
14. Golden tests pass under both Erlang and JavaScript targets.
15. The layer does not implement full algebraic equivalence yet.

## Example End-To-End Flows

## Flow 1: Evaluate a simple expression

Input:

```text
expression: 2x + 6
assignment: {x: 3}
```

Result:

```text
12
```

## Flow 2: Runtime error

Input:

```text
expression: 1 / x
assignment: {x: 0}
```

Result:

```text
DivisionByZero
```

## Flow 3: Generate samples

Input:

```text
variables: [x]
domain: x in [-10, 10]
seed: 42
count: 8
```

Result:

```text
[
  {x: 0},
  {x: 1},
  {x: -1},
  {x: 2},
  ...pseudo-random deterministic values...
]
```

## Flow 4: Generate valid samples for expression

Input:

```text
expression: 1 / x
variables: [x]
domain: x in [-2, 2]
seed: 42
count: 4
```

Possible behavior:

```text
candidate {x: 0} -> DivisionByZero -> reject and retry
candidate {x: 1} -> valid
candidate {x: -1} -> valid
candidate {x: 2} -> valid
candidate {x: -2} -> valid
```

Result:

```text
4 valid samples
1 rejected sample because DivisionByZero
```

## Flow 5: Compare numeric values

Input:

```text
expected: 100
actual: 101
rel tolerance: 1%
```

Result:

```text
passed: true
difference: 1
relative threshold: 1
```

## Future Equivalence Preview

This feature does not implement equivalence, but it should make the future equivalence layer almost obvious.

Future equivalence will look like:

```text
1. Parse and normalize expected expression.
2. Parse and normalize candidate expression.
3. Validate allowed variables and functions.
4. Generate valid samples for the expected expression.
5. Evaluate both expressions at each sample assignment.
6. If candidate errors at an expected-valid sample, fail or report domain mismatch.
7. Compare numeric values with tolerance.
8. If all samples pass, accept as equivalent.
9. If any sample fails, report non-equivalence with diagnostic details.
```

This is why the current feature should remain independent and focused.

## Key Risks

## Risk 1: Accidental nondeterminism

If any part of sampling depends on target runtime randomness, map ordering, floating formatting, or unstable iteration, browser/server parity can break.

Mitigation:

- pure Gleam PRNG
- deterministic variable ordering
- list-based assignment representation or explicit sorting
- cross-target golden tests

## Risk 2: Domain behavior becomes confusing

Authors may not understand why a sample point is invalid or why not enough samples can be found.

Mitigation:

- structured rejected sample summaries
- preview messages with suggested fixes
- simple default domains
- do not infer too much silently

## Risk 3: Evaluator accidentally becomes a CAS

There may be temptation to add simplification during evaluation.

Mitigation:

- evaluator only computes numeric values for concrete assignments
- normalization remains separate
- equivalence remains separate
- no expansion/factoring/cancellation here

## Risk 4: Floating-point behavior surprises users

Functions and powers can produce tiny numeric differences.

Mitigation:

- tolerance comparison helper
- clear default tolerance policy later
- diagnostic comparison details

## Risk 5: Sampling false positives

Sampling can accept a wrong expression if sample points are unlucky.

Mitigation:

- special points plus pseudo-random points
- avoid correlated variables
- sufficient default sample count
- expose sample count as advanced config later
- exact-form and stricter modes remain separate

## Open Questions

These do not need to block the first implementation, but they should be recorded.

1. Should `0^0` be invalid or treated as `1` for calculator-style behavior?
2. What default tolerance should Math Expression equivalence eventually use?
3. Should factorial max be `170`, lower, or author-configurable?
4. Should tangent use an epsilon threshold, exact `cos(x) == 0`, or both?
5. Should default sample count be `8`, `10`, or configurable by author only in advanced mode?
6. Should default domains vary by detected functions, such as positive defaults for `ln(x)`? Recommendation: not in MVP.
7. Should valid samples be unique only, or can duplicates be allowed when the domain is very small?
8. How much diagnostic detail should author preview expose versus developer preview?
9. Should PRNG seed be item-level, response-level, or derived from stable expression/config hash?

## Recommended Answers To Open Questions For MVP

These are opinionated defaults to keep the implementation moving.

1. Treat `0^0` as invalid.
2. Use internal default tolerance of `abs=1e-9`, `rel=1e-9`, `epsilon=1e-12` for equivalence experiments; revisit for production grading.
3. Use factorial max `170` or a lower conservative cap if preferred.
4. Use tangent epsilon `1e-12`.
5. Use default valid sample count `8`.
6. Do not infer function-specific domains yet.
7. Prefer unique samples; return insufficient samples if the domain is too small.
8. Developer preview can show full details; author preview should show summarized actionable diagnostics.
9. Use an explicit seed in config. If missing, derive a stable seed from item/response identity later, not from runtime randomness.

## Summary

This feature is the numeric execution foundation for Math Expression grading.

It should prove that Torus can:

- evaluate expressions at concrete assignments
- detect runtime math errors cleanly
- represent variable assignments and domains
- generate deterministic sample points
- retry invalid samples
- compare numeric values with tolerance
- behave identically across BEAM and JavaScript targets

It should **not** prove algebraic equivalence yet.

That restraint is important.

Once this layer is correct, algebraic equivalence becomes a well-scoped policy over these primitives instead of a tangled mix of parsing, normalization, sampling, evaluation, tolerance, and feedback.
