# Math AST Normalization Design

## Purpose

This document captures the recommended design boundary for the next Torus Math feature layer: **normalization of parsed math expression ASTs**.

The parser milestone is complete and now provides a pure Gleam parser, shared Erlang and JavaScript target support, stable AST values for the MVP ASCII expression syntax, structured parse errors, metadata, and prototype UI integration. The next question is what the normalization layer should do, and where it crosses the line into expression simplification.

The central recommendation is:

> **Normalization makes the same expression shape stable. Simplification tries to find a better, smaller, or more mathematically transformed equivalent expression.**

Those are related, but they are not the same thing.

For Torus, the normalization layer should be deterministic, bounded, cross-target stable, and useful for hashing, diagnostics, validation, and later evaluation. It should not become a general-purpose symbolic algebra system.

---

## Working Definition

A good Torus definition is:

> **Normalization is a deterministic, semantics-preserving AST transformation that converts parsed expressions into a stable internal shape for hashing, diagnostics, evaluation, and later equivalence checks. Normalization is not responsible for proving algebraic equivalence, choosing the simplest expression, expanding, factoring, cancelling rational expressions, or applying assumption-dependent identities.**

This definition keeps normalization aligned with the broader roadmap. Normalization comes after parsing and before deterministic evaluation, sampling, and algebraic equivalence. It prepares expressions for later layers, but it does not decide correctness by itself.

---

## Why This Boundary Matters

“Normalization” can sound like a harmless cleanup step, but it can easily turn into a symbolic algebra system if the scope is not explicit.

For example, these are very different kinds of transformations:

```text
x + 2  ->  2 + x
```

This is mostly canonical ordering.

```text
2(x + 3)  ->  2x + 6
```

This is expansion.

```text
(x^2 - 1) / (x - 1)  ->  x + 1
```

This is rational simplification, and it changes the domain unless the removed restriction `x ≠ 1` is preserved.

```text
sqrt(x^2)  ->  x
```

This is assumption-dependent and is only valid under additional constraints such as `x >= 0`.

The key design point is:

> **Normalization may rearrange and canonicalize. It should not remove operations that can introduce undefinedness unless it also preserves the removed domain guard.**

That means transformations such as `x / x -> 1` are not safe basic normalization unless the result carries a guard such as `x != 0`.

---

## Normalization Versus Simplification

For Torus, normalization should be:

```text
deterministic
bounded
local where possible
cross-target stable
mostly domain-preserving
useful for hashing, comparison, diagnostics, and later evaluation
```

Simplification is broader:

```text
heuristic or algorithmic
potentially expensive
sometimes domain-changing
often assumption-dependent
sometimes goal-dependent: expanded, factored, collected, reduced, etc.
```

The safest design is to avoid a single generic `simplify` operation. Instead, build named, testable transformation passes with clear contracts.

For example:

```text
structural_normalize
collect_like_terms
to_polynomial_normal_form
to_rational_normal_form_with_guards
```

Each pass should have a precise scope and test corpus.

---

## What Basic Normalization Should Allow

The first normalization layer should focus on structural, deterministic transformations.

These are appropriate for basic normalization:

| Input | Normalized idea | Why it is safe enough |
|---|---|---|
| `x + 2` and `2 + x` | Ordered additive terms | Same commutative structure |
| `x * 2` and `2x` | Ordered multiplicative factors | Same commutative structure |
| `(x + y) + z` | Flat sum `[x, y, z]` | Associative flattening |
| `(x * y) * z` | Flat product `[x, y, z]` | Associative flattening |
| `2 + 3` | `5` | Literal-only constant folding |
| `2 * 3 * x` | `6 * x` | Literal factor folding |
| `+x` | `x` | Syntax cleanup |
| `x - y` | Canonical subtract form or `x + (-y)` | Stable internal shape |
| `2(x+3)` | Explicit multiply node with implicit-multiply metadata retained | Parser sugar normalized, source style preserved |
| `1.20e1` | Numeric literal with canonical numeric value plus raw metadata | Useful for value comparison and form checks |

These operations make the AST more regular without trying to solve algebra.

---

## What Basic Normalization Should Avoid

These transformations should not be part of the first normalization layer:

| Rewrite | Why it crosses into simplification |
|---|---|
| `2(x+3) -> 2x + 6` | Distribution/expansion changes expression form |
| `2x + 6 -> 2(x+3)` | Factoring is goal-dependent |
| `(x^2 - 1)/(x - 1) -> x + 1` | Cancels a denominator and changes domain unless guards are tracked |
| `sqrt(x^2) -> x` | Only valid under assumptions like `x >= 0` |
| `sin(x)^2 + cos(x)^2 -> 1` | Trig identity simplification |
| `log(a) + log(b) -> log(ab)` | Assumption/domain-dependent |
| `x/x -> 1` | Invalid at `x = 0` unless domain guards are preserved |
| `0 * f(x) -> 0` | Can erase undefined subexpressions, such as `0 * (1/(x-x))` |

The important danger is domain preservation. Two expressions can have the same value at many points but not the same domain. Basic normalization should not hide those differences.

---

## Recommended Normalization Levels

Normalization should be explicitly layered.

### Level 1: Structural Normalization

This is the recommended MVP normalization layer.

It handles:

```text
parser sugar cleanup
associative flattening
commutative sorting
literal-only constant folding
stable sort keys
stable normalized debug strings
stable normalized hashes
metadata preservation
```

Examples:

```text
x + 2        -> Add([2, x])
2 + x        -> Add([2, x])

x * 2        -> Mul([2, x])
2x           -> Mul([2, x]) with original implicit-multiply metadata retained

(x + y) + z  -> Add([x, y, z])
x + (z + y)  -> Add([x, y, z])

2 * 3 * x    -> Mul([6, x])
```

This is the layer to build first.

### Level 2: Polynomial-Lite Normalization

This starts combining like terms and powers in restricted cases.

Examples:

```text
x + x        -> 2x
2x + 3x      -> 5x
x * x        -> x^2
x^2 * x^3    -> x^5
```

This is already closer to simplification, but it can be reasonable if limited to a clearly defined polynomial subset over allowed variables.

This should not be the first milestone.

### Level 3: Polynomial Normal Form

This is where expansion becomes explicit.

Examples:

```text
2(x + 3)        -> 2x + 6
(x + 1)(x - 1)  -> x^2 - 1
```

This can be useful for equivalence, but it should be a named mode such as:

```text
to_polynomial_normal_form
```

It should not be hidden inside generic normalization.

### Level 4: Rational Normal Form

This is where rational expressions are combined or reduced.

Examples:

```text
1/x + 1/y  ->  (x + y) / (xy)
```

or:

```text
(x^2 - 1)/(x - 1)  ->  x + 1 with guard x != 1
```

This can be powerful, but it must be domain-aware. It should be deferred until there is a clear guard representation.

### Level 5: Heuristic Simplification

This is the CAS-like layer.

Examples:

```text
try many transformations
choose shorter expression
apply identities
use assumptions
maybe expand, factor, cancel, collect
```

This should be explicitly out of scope for the core Torus MVP.

---

## The Key Border: Domain Preservation

The most important boundary is domain preservation.

A rewrite is safe normalization only if it preserves both:

```text
value behavior
domain behavior
```

For example:

```text
(x^2 - 1) / (x - 1)
```

and:

```text
x + 1
```

have the same value for most `x`, but they do not have the same domain. The first expression is undefined at `x = 1`; the second is defined there.

So this rewrite is unsafe as plain normalization:

```text
(x^2 - 1) / (x - 1)  ->  x + 1
```

unless the normalized result becomes something like:

```text
Guarded(expr: x + 1, requires: x != 1)
```

That is a later rational-simplification feature, not Level 1 structural normalization.

The same problem appears here:

```text
x / x  ->  1
```

This rewrite is not valid at `x = 0`.

And here:

```text
0 * (1 / (x - x))  ->  0
```

The expression on the left is undefined, while `0` is defined.

Therefore:

> **Do not remove potentially undefined subexpressions in basic normalization.**

---

## Recommended Normalized Representation

Do not simply mutate or reuse the parsed AST as the normalized representation. Create a separate normalized AST.

A possible shape:

```gleam
pub type NormalExpr {
  NNumber(ExactNumber)
  NVariable(String)
  NConstant(Constant)
  NSum(List(NormalExpr))
  NProduct(List(NormalExpr))
  NPower(base: NormalExpr, exponent: NormalExpr)
  NCall(name: FunctionName, args: List(NormalExpr))
  NAbs(NormalExpr)
  NFactorial(NormalExpr)
}
```

Then wrap it with metadata:

```gleam
pub type Normalized {
  Normalized(
    original: Expr,
    normal: NormalExpr,
    source_map: SourceMap,
    warnings: List(NormalizationWarning),
  )
}
```

This matters because later exact-form checks need the original expression.

For example:

```text
4/5
8/10
0.8
```

These may be numerically equivalent, but they are not the same representation. Exact-form checks such as simplified fraction, decimal precision, or integer-only form require source-level information.

So the system should keep both:

```text
raw parsed AST
normalized AST
```

Do not throw away source form.

---

## Exact Numbers And Cross-Target Stability

For normalization, exact numeric representation is preferable where possible.

A possible model:

```gleam
pub type ExactNumber {
  Integer(Int)
  Rational(numerator: Int, denominator: Int)
  Decimal(raw: String, rational: Rational)
  FloatApprox(Float)
}
```

For finite decimals and scientific notation, many values can be represented exactly as rationals:

```text
1.2e-3 -> 12 / 10000 -> 3 / 2500
0.8    -> 8 / 10 -> 4 / 5
```

That is useful for constant folding and fraction checks.

However, because this parser and normalizer must run on both BEAM and JavaScript, avoid introducing cross-target numeric differences. JavaScript has a safe integer limit, so exact rational folding should either:

```text
limit exact rational folding to safe-size integers
```

or:

```text
store large exact numbers as decimal strings until a later big-number strategy exists
```

The normalizer should not turn a cross-target parser into a cross-target inconsistency problem.

---

## First-Pass Normalization Algorithm

The first production-worthy normalizer should use a simple deterministic sequence:

```text
1. Recursively normalize children.
2. Desugar syntactic variants.
3. Flatten nested Add nodes.
4. Flatten nested Multiply nodes.
5. Fold literal-only numeric operations.
6. Move numeric coefficient to the front of products.
7. Move numeric constant to a consistent position in sums.
8. Sort commutative operands using a stable sort key.
9. Preserve source metadata and original expression references.
10. Emit a stable normalized debug string.
11. Hash that debug string.
```

Example:

```text
Input:
x*2 + 3 + y + x

Structural normalized:
Add([
  Number(3),
  Mul([Number(2), Var("x")]),
  Var("x"),
  Var("y")
])
```

If like-term collection is not implemented yet, do not force:

```text
2x + x -> 3x
```

That belongs to polynomial-lite normalization.

---

## Stable Sort Keys

Commutative sorting requires a stable sort key. This is important because the same expression should normalize identically across Erlang and JavaScript targets.

A simple first sort order could be:

```text
1. Numbers
2. Constants
3. Variables
4. Powers
5. Products
6. Sums
7. Function calls
8. Absolute value
9. Factorial
```

Within each class, sort lexicographically by a stable normalized debug string.

For example:

```text
y + 2 + x
x + y + 2
```

could both normalize to:

```text
Add([Number(2), Var("x"), Var("y")])
```

Do not sort using runtime object representations or target-specific inspect output. Generate your own stable debug string.

---

## Expected Behavior Examples

### Should normalize to the same structure

These should normalize to the same structure:

```text
2x + 6
x*2 + 6
6 + 2*x
```

Reason: these only require commutative ordering and explicit/implicit multiplication normalization.

### Should not necessarily normalize to the same structure yet

These should not necessarily normalize to the same structure in Level 1:

```text
2(x + 3)
2x + 6
```

Reason: making these the same requires expansion or polynomial normal form. That is algebraic simplification, not structural normalization.

They can still be judged equivalent later by deterministic sampling.

### Should definitely not normalize to the same unguarded structure

These should not normalize to the same unguarded structure:

```text
(x^2 - 1)/(x - 1)
x + 1
```

Reason: they differ at `x = 1`.

### Should not simplify without assumptions

These should not normalize to the same structure:

```text
sqrt(x^2)
x
```

Reason: the rewrite depends on assumptions about `x`.

---

## Interaction With Algebraic Equivalence

Normalization should give cheap wins:

```text
x + 2 == 2 + x
2*x == x*2
(x+y)+z == x+(y+z)
```

But it should not be responsible for all equivalence.

For algebraic equivalence, the later evaluator should still do:

```text
parse expected
parse candidate
normalize both
validate variables/domains
evaluate both at deterministic sample points
compare numeric results with tolerance
report syntax/domain/non-equivalence separately
```

Normalization prepares the AST. Sampling and evaluation make the equivalence decision.

This is important because some expressions are equivalent but should not become structurally identical through basic normalization:

```text
2(x + 3)
2x + 6
```

Those can be accepted by algebraic equivalence sampling without requiring the normalizer to expand expressions.

---

## Interaction With Exact Form Constraints

Exact-form constraints should operate on the original parsed AST and metadata, not only the normalized AST.

Examples:

```text
Expected: 4/5
Student: 8/10
```

The student answer may be numerically equivalent, but if the author requires `simplified_fraction`, it should fail the form check.

```text
Expected: 0.80
Student: 0.8
```

The values are equivalent, but if the author requires exactly two decimal places, the raw numeric literal matters.

Therefore, normalization should not erase:

```text
raw numeric literals
fraction syntax
decimal places
scientific notation
implicit versus explicit multiplication metadata
source spans
```

Normalization should create a stable semantic representation, not destroy the original representation.

---

## Recommended Gleam API Shape

A reasonable public API could look like this:

```gleam
pub fn normalize(expr: Expr) -> Normalized

pub fn normalize_with_options(
  expr: Expr,
  options: NormalizationOptions,
) -> Normalized
```

Options should be explicit:

```gleam
pub type NormalizationLevel {
  Structural
  PolynomialLite
  PolynomialNormalForm
  RationalNormalForm
}

pub type NormalizationOptions {
  NormalizationOptions(
    level: NormalizationLevel,
    preserve_source: Bool,
  )
}
```

For grading-related work, the default should be:

```gleam
Structural
```

Do not use aggressive modes in production grading until they have precise contracts and robust tests.

For the immediate MVP, you could avoid exposing multiple levels and simply implement:

```gleam
pub fn structural_normalize(expr: Expr) -> Normalized
```

That may be even clearer.

---

## Warning Model

Normalization can emit warnings when it detects expressions that are valid but risky or ambiguous.

Possible warning type:

```gleam
pub type NormalizationWarning {
  AmbiguousImplicitMultiplication(span: Span)
  LargeExactNumberKeptAsString(span: Span)
  DomainSensitiveRewriteSkipped(span: Span)
  PolynomialNormalizationUnavailable(span: Span)
}
```

For Level 1, most warnings should probably be developer-preview diagnostics rather than student-facing messages.

Example:

```text
Input:
1/2x

Warning:
Ambiguous implicit multiplication; interpreted as (1/2) * x.
```

This kind of warning can be surfaced in the prototype UI or author preview later.

---

## Testing Strategy

The normalization test suite should be as important as the parser golden tests.

### Determinism Tests

The same input should produce the same normalized debug string and hash across Erlang and JavaScript targets.

```text
gleam test --target erlang
gleam test --target javascript
```

### Structural Equivalence Tests

Inputs that should normalize the same:

```text
x + 2
2 + x

x * 2
2x
2 * x

(x + y) + z
x + (z + y)

2 * 3 * x
6x
```

### Non-Equivalence Tests

Inputs that should not normalize the same at Level 1:

```text
2(x + 3)
2x + 6

(x^2 - 1)/(x - 1)
x + 1

sqrt(x^2)
x

sin(x)^2 + cos(x)^2
1
```

### Metadata Preservation Tests

Ensure raw/source information survives:

```text
0.80
0.8
8/10
4/5
1.2e-3
0.0012
2x
2*x
```

These may normalize to similar or identical semantic values, but exact-form metadata must remain distinguishable.

---

## Recommended First Milestone

Build **structural normalization only** first.

That means:

```text
yes: stable shape
yes: stable ordering
yes: safe literal folding
yes: normalized hashes
yes: metadata preservation

no: expansion
no: factoring
no: cancellation
no: trig identities
no: assumption-dependent rewrites
no: “make it simpler”
```

Then add named, testable passes later:

```text
collect_like_terms
to_polynomial_normal_form
to_rational_normal_form_with_guards
```

The moment a pass needs assumptions, changes domains, expands/factors, cancels denominators, or chooses one “simpler” expression among several possible equivalent forms, it has crossed from **normalization** into **simplification**.

---

## Summary Recommendation

For the next Torus Math milestone, implement a Level 1 structural normalizer that:

1. Accepts the parsed AST from the completed Gleam parser.
2. Produces a separate normalized AST.
3. Preserves the original parsed AST and source metadata.
4. Flattens associative addition and multiplication.
5. Sorts commutative operands with a stable sort key.
6. Performs safe literal-only constant folding.
7. Emits stable normalized debug strings and hashes.
8. Runs deterministically on both Erlang and JavaScript targets.
9. Avoids expansion, factoring, cancellation, trig identities, and assumption-dependent rewrites.

This gives the later evaluator a clean, deterministic internal representation without turning the MVP into a symbolic algebra project.
