# Exact Form And Representation Constraints - Informal PRD And Technical Approach

## 1. Executive Summary

Implement **Exact Form And Representation Constraints** as the next Torus Math layer after algebraic equivalence.

This feature answers a question that semantic equality deliberately does not answer:

> The submitted answer has the right mathematical value. Did the learner write it in the form the author required?

Examples:

```text
Expected: 4/5
Student:  0.8
Semantic result: equivalent
Form result: wrong form when simplified fraction is required
```

```text
Expected: 0.8
Student:  0.80
Semantic result: equivalent
Form result: pass when decimal with exactly 2 places is required
```

Exact-form checks must refine semantic correctness. They must not replace numeric comparison, algebraic equivalence, parsing, validation, domain handling, tolerance comparison, or future feedback-rule matching.

The first implementation should focus on representation constraints that can be proven from the submitted expression's original parsed AST and numeric-literal metadata:

- integer-only form;
- fraction/rational-only form;
- simplified fraction form;
- decimal form with decimal-place precision rules;
- structured form-failure categories such as `WrongForm`, `UnsimplifiedFraction`, and `DecimalPrecisionMismatch`.

Advanced expression-form requirements such as factored form, expanded form, collected terms, simplified radicals, rational-expression canonical form, or style constraints around implicit multiplication are out of scope for this phase.

## 2. Product Goal

Authors need to require a specific representation when representation is part of the learning objective.

For example, an answer can be mathematically correct but pedagogically wrong:

- `7.0` is numerically equal to `7`, but it is not an integer-only submission.
- `8/10` is equivalent to `4/5`, but it is not a simplified fraction.
- `0.8` is equivalent to `0.80`, but it does not have exactly two decimal places.
- `4/5` is equivalent to `0.8`, but it is not decimal form.

This feature should produce deterministic, structured facts that future activity evaluation and feedback-rule layers can use. It should not choose final feedback text or scores by itself.

## 3. Why This Comes Now

The prior math layers created the exact prerequisites this feature needs:

- `gleam/src/math/ast.gleam`
  - `NumberLiteral` preserves `raw`, numeric `value`, `notation`, and `decimal_places`.
  - every expression carries a source `Span`.
  - multiplication preserves explicit versus implicit style.
- `gleam/src/math/lexer.gleam`
  - numeric tokens retain raw source and notation metadata.
  - whitespace metadata is retained on tokens for future unit parsing.
- `gleam/src/math/parser.gleam`
  - fraction syntax is represented as `Binary(Divide, left, right)`.
  - unary signs are represented as `Prefix`.
  - grouping affects spans but does not introduce a separate grouping node.
- `gleam/src/math/normalization/types.gleam`
  - `Normalized.original` keeps the parsed AST beside the normalized expression.
  - `NNumber` keeps the original `NumberLiteral` as `source`.
  - exact decimal and integer representations are preserved conservatively.
- `gleam/src/math/equality/algebraic.gleam`
  - algebraic equivalence already returns structured semantic outcomes.
  - candidate runtime failure, value mismatch, parse failure, validation failure, and insufficient sampling are distinct.
- `gleam/src/math/equality/numeric.gleam`
  - Number-input scalar representation and decimal-place checks already exist for broad integer, decimal, and scientific notation.
  - those checks are string-based and scoped to Number input scalar behavior, not expression AST form.

The important architectural lesson is that normalization and equivalence are intentionally not enough for exact form. Normalization can make `2x` and `2*x` look the same, and equivalence can make `4/5`, `8/10`, and `0.8` all pass semantically. Exact-form checks must inspect the submitted source shape before those details are erased or ignored.

## 4. Strong Product Position

Exact form is a **post-semantics constraint layer**.

The evaluation order should be:

```text
parse candidate
validate candidate
compare candidate to expected semantically
if semantically equivalent:
  inspect candidate representation
  apply configured form constraints
else:
  preserve the semantic failure as the primary outcome
```

This means:

- A syntax error is not a form failure.
- An unexpected variable is not a form failure.
- A non-equivalent expression is not a form failure.
- A candidate runtime failure is not a form failure.
- `8/10` against expected `4/5` can be `EquivalentButWrongForm(UnsimplifiedFraction)`.
- `8/11` against expected `4/5` is `NotEquivalent`, not `UnsimplifiedFraction`.

Tests should prove this ordering explicitly.

## 5. MVP Scope

### In scope

- A typed exact-form config for expression answers.
- A source-shape classifier over parsed candidate ASTs.
- Raw-string form checking through the public `torus_math` boundary.
- Form-aware algebraic checking for raw expected/candidate strings.
- Integer-only, fraction-only, simplified-fraction, and decimal-form constraints.
- Decimal-place precision rules: exactly, at least, and at most N places.
- Structured form result taxonomy and stable debug formatting.
- Cross-target Gleam tests on Erlang and JavaScript.
- Prototype support in the existing developer-only Math Prototype LiveView if the implementation phase includes UI work.
- Tests proving form checks only run as correctness refinements after semantic pass.

### Out of scope

- Production Short Answer, Multi-Input, Number, or legacy Math grading integration.
- Production authoring UI or learner UI changes.
- Database, activity JSON, response-rule, publication, section, or attempt schema changes.
- Unit parsing or unit-aware exact form.
- LaTeX form preservation.
- Factored, expanded, collected, radical, polynomial, or rational-expression form requirements.
- Scoring, partial credit, feedback text selection, feedback-rule ordering, or author linting.
- Locale-specific decimal separators or thousands separators.
- Treating scientific notation as decimal form.

## 6. User Stories

### Future author: require an integer

As an author, I want to require integer form for an answer such as `7`, so that `7` passes but `7.0`, `7/1`, and `14/2` fail the representation rule even though they are mathematically equal.

### Future author: require a simplified fraction

As an author, I want to require simplified fraction form for an answer such as `4/5`, so that `4/5` passes, `8/10` fails with an unsimplified-fraction category, and `0.8` fails with a wrong-form category.

### Future author: require decimal precision

As an author, I want to require decimal form with exactly two decimal places, so that `0.80` passes while `0.8` and `0.800` fail precision even though all three have the same numeric value.

### Developer: debug form outcomes

As a developer, I want stable form diagnostics showing the observed representation, required representation, relevant spans, and numeric literal metadata, so that exact-form behavior can be tested without relying on target-specific inspect output.

## 7. Guiding Principles

### 7.1 Form checks inspect source shape

The form checker should use the parsed candidate AST and raw numeric literal metadata. It should not infer submitted form from evaluated `Float` values.

For example:

```text
0.80
```

must remain distinguishable from:

```text
0.8
```

even though both evaluate to the same value.

### 7.2 Semantic correctness remains authoritative

The form checker should not decide whether two expressions are mathematically equal. It only answers whether a semantically accepted candidate satisfies extra representation rules.

### 7.3 Whole-answer form only in the MVP

The first exact-form feature should classify the whole submitted answer, not arbitrary subexpressions.

Examples:

| Candidate | Required form | MVP result |
|---|---|---|
| `7` | integer | pass |
| `3 + 4` | integer | wrong form |
| `7.0` | integer | wrong form |
| `4/5` | simplified fraction | pass |
| `8/10` | simplified fraction | unsimplified fraction |
| `1/(x+1)` | fraction | wrong form or unsupported form constraint for non-scalar rational expressions |

This keeps the MVP aligned with the listed roadmap requirements and avoids accidentally implementing a rational-expression form system.

### 7.4 Normalized APIs cannot enforce exact form by themselves

The existing normalized-expression algebraic API accepts `NormalExpr` values. That representation is not enough to prove original submitted form in every case. Exact-form APIs should therefore require either:

- the raw candidate string; or
- the original parsed candidate AST.

Do not add exact-form enforcement to APIs that only receive normalized expressions unless the caller separately provides source-form metadata.

### 7.5 Diagnostics are categories, not final feedback

This feature can return categories such as `wrong_form` and `unsimplified_fraction`. It should not select final learner-facing feedback text, score, or rule match. That belongs to the later feedback and activity integration layer.

## 8. Proposed Design

### 8.1 New Gleam modules

Add a focused expression-form subsystem under `gleam/src/math/equality/`:

```text
gleam/src/math/equality/form_types.gleam
gleam/src/math/equality/form.gleam
gleam/src/math/equality/form_format.gleam
```

The module name should stay under `math/equality` because form constraints refine equality outcomes. If implementation discovers useful generic AST-shape helpers, those can live under `gleam/src/math/`, but the public product contract should remain equality-oriented.

### 8.2 Core config types

Recommended typed shape:

```gleam
pub type ExactFormConfig {
  NoFormConstraint
  RequireInteger
  RequireFraction
  RequireSimplifiedFraction
  RequireDecimal(precision: DecimalPrecisionConstraint)
}

pub type DecimalPrecisionConstraint {
  AnyDecimalPlaces
  DecimalPlaces(rule: DecimalPlaceRule, count: Int)
}

pub type DecimalPlaceRule {
  Exactly
  AtLeast
  AtMost
}
```

Notes:

- `RequireFraction` means a single rational literal shape such as `4/5`, not any expression containing division.
- `RequireSimplifiedFraction` is stricter than `RequireFraction`.
- `RequireDecimal(AnyDecimalPlaces)` requires decimal notation but no decimal-place count.
- The decimal-place rule should mirror the existing `types.DecimalPlaceRule` vocabulary unless the implementation chooses to reuse that type directly.
- The initial form config should not include scientific notation unless product scope is deliberately expanded. The current Number scalar evaluator already has `ScientificRepresentation`; expression exact-form MVP does not need it.

### 8.3 Observed form classification

The checker should first classify the submitted candidate into an observed whole-answer form:

```gleam
pub type ObservedForm {
  ObservedInteger(literal: SignedIntegerLiteral)
  ObservedDecimal(literal: SignedDecimalLiteral)
  ObservedFraction(fraction: FractionLiteral)
  ObservedOther(span: ast.Span)
}
```

Suggested helper shapes:

```gleam
pub type SignedIntegerLiteral {
  SignedIntegerLiteral(sign: Sign, raw_digits: String, value: Int, span: ast.Span)
}

pub type SignedDecimalLiteral {
  SignedDecimalLiteral(
    sign: Sign,
    raw: String,
    decimal_places: Int,
    span: ast.Span,
  )
}

pub type FractionLiteral {
  FractionLiteral(
    sign: Sign,
    numerator_raw: String,
    numerator: Int,
    denominator_raw: String,
    denominator: Int,
    span: ast.Span,
  )
}

pub type Sign {
  Positive
  Negative
}
```

The implementation can keep these types private if the public result contains enough structured detail. The important point is that the checker should normalize superficial sign placement while preserving raw component strings for diagnostics.

### 8.4 Accepted MVP surface shapes

#### Integer form

Accept:

```text
7
-7
+7
```

Reject:

```text
7.0
7/1
14/2
3+4
7e0
```

Implementation rule:

- The parsed expression is a single integer `NumberLiteral`, optionally wrapped by unary `+` or unary `-`.
- The underlying literal notation is `IntegerNotation`.
- The integer must parse within the shared safe integer range if the checker needs an `Int` value for details. If not safe, it can still classify as integer form but should carry a large-number diagnostic or raw-only detail.

#### Fraction form

Accept:

```text
4/5
-4/5
(-4)/5
4/(-5)
-(4/5)
```

Reject:

```text
0.8
4
4/5/2
1/(x+1)
x/y
4.0/5
4/5.0
```

Implementation rule:

- The whole expression is a single division between integer literal numerator and integer literal denominator, allowing unary signs on the whole fraction or either side.
- The denominator must be non-zero for form classification to pass. If semantic evaluation has already passed, denominator zero should not occur for an accepted candidate, but the form module should still avoid treating it as a valid fraction.
- Numerator and denominator are normalized to one sign on the whole fraction for simplified checks.

#### Simplified fraction form

Accept:

```text
4/5
-4/5
0/1
```

Reject:

```text
8/10
4/6
0/5
4/-5 only if the project chooses a canonical-denominator-positive style
```

Implementation rule:

- First classify as fraction form.
- Compute `gcd(abs(numerator), abs(denominator))`.
- The fraction is simplified when `gcd == 1`.
- Prefer requiring a positive denominator in the first implementation. That makes `-4/5` canonical and lets `4/-5` be either normalized internally for value comparison or reported as non-canonical fraction style. If this is too strict for product expectations, the PRD should explicitly choose the looser rule before implementation.
- For zero numerators, require denominator `1` if simplified-fraction form is strict. This makes `0/5` unsimplified.

#### Decimal form

Accept:

```text
0.8
-0.8
0.80
```

Reject:

```text
.8
8
4/5
8e-1
0.8 + 0
```

Implementation rule:

- The parsed expression is a single decimal `NumberLiteral`, optionally wrapped by unary `+` or unary `-`.
- The underlying literal notation is `DecimalNotation`.
- Decimal places come from `NumberLiteral.decimal_places`.
- Scientific notation is not decimal form in the MVP, even when the mantissa has decimal places.
- Leading-dot decimals are currently rejected by the expression lexer, so `.8` is not a decimal-form candidate for Math Expression inputs. The Number scalar evaluator can continue accepting leading-dot forms for legacy compatibility.

### 8.5 Form result types

Recommended result shape:

```gleam
pub type FormCheckResult {
  FormSatisfied(observed: ObservedFormSummary)
  FormNotSatisfied(
    observed: ObservedFormSummary,
    failures: List(FormFailure),
  )
  FormCheckParseFailed(error: ast.ParseError)
  InvalidFormConfig(error: FormConfigError)
}

pub type FormFailure {
  WrongForm(required: RequiredForm, observed: ObservedFormKind)
  UnsimplifiedFraction(
    numerator: Int,
    denominator: Int,
    gcd: Int,
  )
  DecimalPrecisionMismatch(
    rule: DecimalPlaceRule,
    expected_count: Int,
    actual_count: Int,
  )
  NonCanonicalFractionSign
  UnsafeIntegerLiteral(raw: String)
}
```

The public summaries should avoid leaking raw submitted answer text by default. Developer debug formatters can include raw numeric literal fragments when used in tests or the developer-only prototype.

### 8.6 Form-aware algebraic result

Do not mutate the core algebraic equivalence result into a form checker. Instead, layer a wrapper result around it:

```gleam
pub type FormAwareAlgebraicResult {
  SemanticsFailed(result: AlgebraicEquivalenceResult)
  SemanticsPassedFormSatisfied(
    equivalence: AlgebraicEquivalenceResult,
    form: FormCheckResult,
  )
  SemanticsPassedFormFailed(
    equivalence: AlgebraicEquivalenceResult,
    form: FormCheckResult,
  )
}
```

Recommended raw-string API:

```gleam
pub fn check_algebraic_equivalence_with_form(
  expected: String,
  candidate: String,
  equivalence_config: AlgebraicEquivalenceConfig,
  form_config: ExactFormConfig,
) -> FormAwareAlgebraicResult
```

This should internally:

1. call `check_algebraic_equivalence`;
2. inspect the algebraic outcome;
3. if the outcome is `Equivalent(_)`, parse/classify/check candidate form;
4. otherwise return `SemanticsFailed` with the original algebraic result.

Reparsing the candidate after semantic pass is acceptable for the MVP because the work is bounded and avoids widening the existing algebraic result with raw ASTs. If implementation wants to avoid reparsing, it can extend `pipeline.PreparedExpression` to retain `original: ast.Parsed`, but that should be treated as an internal optimization.

### 8.7 Exact expression mode

The existing equality contract has `ExpressionComparison.ExactExpression(expected)`. Exact-form constraints are related but not identical.

Recommended semantics:

- `ExactExpression` means the comparison mode itself is exact structural or exact written-form comparison, depending on how that earlier placeholder is later defined.
- `ExactFormConfig` means semantic comparison can still be algebraic equivalence, but the accepted candidate must additionally satisfy a representation rule.

Do not collapse these into one setting. Authors need to be able to say:

```text
Compare algebraically, but require simplified fraction form.
```

That is different from:

```text
Only accept this exact expression.
```

### 8.8 Equality config JSON

Extend the expression equality JSON contract with a form object when production storage work reaches this phase:

```json
{
  "version": 1,
  "mode": "expression",
  "comparison": {
    "type": "algebraic_equivalence",
    "expected": "4/5",
    "sampling": { "seed": 42, "sampleCount": 8 }
  },
  "validation": {
    "allowedVariables": [],
    "allowedFunctions": [],
    "domains": []
  },
  "form": {
    "type": "simplified_fraction"
  }
}
```

Decimal example:

```json
{
  "form": {
    "type": "decimal",
    "precision": {
      "type": "decimal_places",
      "rule": "exactly",
      "count": 2
    }
  }
}
```

No-form example:

```json
{
  "form": {
    "type": "none"
  }
}
```

If this phase does not integrate production JSON decoding yet, the informal spec should still name this shape so the Gleam type contract can evolve in the right direction.

## 9. Data Flow

### 9.1 Raw candidate form check

```text
candidate string
  -> parser.parse
  -> ast.Parsed
  -> classify whole-answer form
  -> apply ExactFormConfig
  -> FormCheckResult
```

This API is useful for isolated tests and developer preview.

### 9.2 Algebraic equivalence with form

```text
expected string + candidate string + algebraic config + form config
  -> check_algebraic_equivalence
  -> if not Equivalent:
       SemanticsFailed(original algebraic result)
     if Equivalent:
       check candidate form
       SemanticsPassedFormSatisfied or SemanticsPassedFormFailed
```

This API proves the roadmap requirement that form constraints refine correctness instead of replacing it.

### 9.3 Numeric scalar relationship

The current Number-input evaluator already supports:

- integer, decimal, and scientific representation constraints;
- decimal-place rules;
- legacy significant-figure rules.

This feature should not casually rewrite Number input behavior. If shared helpers are extracted, the implementation must preserve the existing tests in `gleam/test/math_equality_numeric_test.gleam`.

Recommended approach:

- Keep Number scalar behavior stable.
- Add expression AST-based form checks separately.
- Optionally extract shared decimal-place rule types or small pure helpers only when tests prove no behavior drift.

## 10. Failure Modes

### Parse failure

If the candidate cannot parse, exact form should not be the primary outcome. The semantic layer should surface `CandidateParseFailed`.

The standalone form-check API can still return `FormCheckParseFailed` for developer tooling.

### Validation failure

Unexpected variables, disallowed functions, invalid domains, and invalid sampling configs are not form failures.

### Non-equivalence

If the candidate is not semantically equivalent, do not report form failure as the correctness result.

Example:

```text
Expected: 4/5
Candidate: 8/11
Required form: simplified_fraction
Outcome: SemanticsFailed(NotEquivalent(...))
```

The candidate may also be an unsimplified fraction shape, but that is not the meaningful correction because the value is wrong.

### Equivalent but wrong form

If the candidate is semantically equivalent and fails the configured representation rule, return a form failure.

Example:

```text
Expected: 4/5
Candidate: 8/10
Required form: simplified_fraction
Outcome: SemanticsPassedFormFailed(UnsimplifiedFraction(...))
```

### Unsupported source shape

When the candidate is a valid expression but not one of the supported whole-answer forms, classify it as `ObservedOther` and fail with `WrongForm`.

Example:

```text
Expected: 7
Candidate: 3 + 4
Required form: integer
Semantic result: equivalent
Form result: wrong form
```

## 11. Public API Recommendations

Add these through `gleam/src/torus_math.gleam` after internal modules are stable:

```gleam
pub fn default_exact_form_config() -> form_types.ExactFormConfig

pub fn check_exact_form(
  candidate: String,
  config: form_types.ExactFormConfig,
) -> form_types.FormCheckResult

pub fn check_algebraic_equivalence_with_form(
  expected: String,
  candidate: String,
  equivalence_config: algebraic_types.AlgebraicEquivalenceConfig,
  form_config: form_types.ExactFormConfig,
) -> form_types.FormAwareAlgebraicResult

pub fn form_check_result_to_debug_string(
  result: form_types.FormCheckResult,
) -> String

pub fn form_aware_algebraic_result_to_debug_string(
  result: form_types.FormAwareAlgebraicResult,
) -> String
```

The public comments should state that exact-form debug strings are for tests, diagnostics, and the developer prototype, not learner-facing feedback text.

## 12. Prototype UI

If this phase extends the existing developer-only Math Prototype LiveView, add exact-form controls to the Algebraic Equivalence panel rather than creating a separate product surface.

Suggested controls:

- form constraint selector:
  - none;
  - integer;
  - fraction;
  - simplified fraction;
  - decimal;
- decimal precision selector:
  - any places;
  - exactly N;
  - at least N;
  - at most N;
- count input for decimal places;
- result display:
  - semantic outcome;
  - form outcome;
  - observed form;
  - form failures;
  - existing algebraic sample details.

The prototype must remain developer-only and must not persist submitted expressions or sampled assignments.

## 13. Testing Strategy

### 13.1 Form classifier tests

Add `gleam/test/math_equality_form_test.gleam`.

Cover:

- integer form:
  - `7`, `-7`, `+7` pass;
  - `7.0`, `7/1`, `14/2`, `3+4`, `7e0` fail.
- fraction form:
  - `4/5`, `-4/5`, `(-4)/5`, `4/(-5)`, `-(4/5)` classify as fraction;
  - `0.8`, `4`, `4/5/2`, `1/(x+1)`, `x/y`, `4.0/5`, `4/5.0` do not.
- simplified fraction:
  - `4/5` passes;
  - `8/10` fails with `UnsimplifiedFraction`;
  - `0/5` follows the selected zero policy, preferably unsimplified unless denominator is `1`.
- decimal form:
  - `0.8`, `-0.8`, `0.80` pass;
  - `8`, `4/5`, `8e-1`, `0.8+0` fail.
- decimal-place rules:
  - `0.80` passes exactly 2;
  - `0.8` fails exactly 2;
  - `0.800` fails exactly 2 but passes at least 2;
  - `0.8` passes at most 2.

### 13.2 Post-semantics ordering tests

Add tests that call the form-aware algebraic API:

- expected `4/5`, candidate `4/5`, required simplified fraction -> semantic pass and form pass.
- expected `4/5`, candidate `8/10`, required simplified fraction -> semantic pass and form failure.
- expected `4/5`, candidate `0.8`, required simplified fraction -> semantic pass and wrong form.
- expected `4/5`, candidate `8/11`, required simplified fraction -> semantic failure, not form failure.
- expected `7`, candidate `3+4`, required integer -> semantic pass and wrong form.
- expected `7`, candidate `3+5`, required integer -> semantic failure, not wrong form.
- malformed candidate -> candidate parse failure, not wrong form.

### 13.3 Numeric behavior preservation tests

Run existing numeric equality tests and add regression tests only if shared helpers are extracted.

Important existing behavior to preserve:

- Number scalar leading decimals remain accepted where currently accepted.
- legacy significant figures remain distinct from decimal-place rules.
- scientific representation remains a Number scalar representation option.
- numeric diagnostics do not emit raw submitted answers.

### 13.4 Cross-target parity

Required commands:

```bash
cd gleam && gleam format --check src test
cd gleam && gleam test --target erlang
cd gleam && gleam test --target javascript
```

If Elixir prototype or bridge files are changed, also run targeted `mix format --check-formatted` and focused ExUnit tests for those files.

## 14. Security And Privacy

- Do not log raw learner expressions, raw expected answers, or sampled assignments.
- Keep raw numeric fragments inside structured developer/test diagnostics only.
- Debug formatters may include raw literals for exact-form troubleshooting, but those strings must not become production telemetry or learner-facing feedback text.
- The developer prototype may render raw expressions because it is already developer-only.
- No dynamic atoms should be created from form config strings in Elixir wrappers.
- Avoid regex-heavy or unbounded source scanning; classify through the parsed AST.

## 15. Performance

Exact-form checks should be cheap and bounded:

- one parse of the candidate for standalone form checks;
- one AST traversal for classification;
- integer parsing and GCD for fraction simplification;
- no sampling, symbolic simplification, expansion, factoring, or repeated evaluation inside the form module.

For form-aware algebraic checking, the expensive work remains the existing algebraic equivalence pass. Form checking only runs after semantic pass and should not affect non-equivalent early exits.

## 16. Open Product Decisions

These should be settled before implementation:

1. Should simplified fraction require a positive denominator?
   - Recommended: yes, so canonical simplified form is `-4/5`, not `4/-5`.
2. Should zero fractions require denominator `1`?
   - Recommended: yes, so `0/5` is unsimplified.
3. Should unary plus be accepted for exact forms?
   - Recommended: yes for parser consistency, though UI examples should not encourage it.
4. Should scientific notation ever satisfy decimal form?
   - Recommended: no for this phase.
5. Should large integer literals outside the shared safe integer range be accepted as integer form?
   - Recommended: classify them as integer form when notation is integer, but do not attempt simplified-fraction arithmetic with unsafe integer components unless a raw big-integer helper is added.
6. Should fraction-only form allow variables, such as `1/x`?
   - Recommended: no for this phase. Treat rational-expression form as a later advanced exact-form requirement.

## 17. Recommended Implementation Sequence

1. Add form config, observed-form, failure, and result types.
2. Implement whole-answer AST classification for integer, decimal, and fraction literals.
3. Implement decimal-place checks and fraction simplification checks.
4. Add stable debug formatting.
5. Expose standalone raw candidate form check through `torus_math`.
6. Add form-aware algebraic wrapper that runs form checks only after `Equivalent`.
7. Add cross-target tests for classifier behavior and post-semantics ordering.
8. Optionally extend the developer Math Prototype LiveView with form controls.
9. Run final Gleam format and both target test suites.

## 18. Definition Of Done

- Exact-form config is typed and invalid precision counts are rejected.
- Candidate source shape is classified from parsed AST metadata, not floats.
- Integer, fraction, simplified fraction, and decimal precision requirements are covered by direct tests.
- Form-aware algebraic checks preserve semantic failures as primary outcomes.
- Equivalent-but-wrong-form outcomes carry structured form-failure categories.
- Debug formatting is target-stable and documented as non-learner-facing.
- Existing numeric scalar representation and precision behavior remains unchanged unless deliberately migrated with tests.
- Erlang and JavaScript Gleam test suites pass.
