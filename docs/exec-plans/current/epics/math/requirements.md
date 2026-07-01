# Math Evaluation: Functional Requirements

## Accepted Syntax (MVP)

- Primary input: ASCII/"calculator-style" math parsed into a single AST and renderable via MathJax/KaTeX.
- Optional input: a small LaTeX subset auto-translated to the same AST; same correctness rules apply.


- ASCII tokens
  - Numbers: integers, decimals, scientific notation like `1.2e-3`.
  - Variables: `x`, `y`, `t`, `a` (author-configurable; validated by FR-014).
  - Operators: `+`, `-`, `*`, `/`, `^`; parentheses `(` `)`; implicit multiplication allowed: `2x`, `2(x+1)`, `xy`.
  - Functions: `sin(x)`, `cos(x)`, `tan(x)`, `ln(x)`, `log(x)`, `log10(x)`, `log2(x)`, `sqrt(x)`, `abs(x)`, `exp(x)`.
  - Constants: `pi`, `e`.
  - Other forms: fractions `a/b`, absolute value `|x|`, factorial `n!`.
  - Units (when enabled): `9.8 m/s^2`, `980 cm/s^2`.

- LaTeX subset (optional)
  - `\frac{a}{b}`, `\sqrt{x}`, `\pi`, `e^{x}`, `x^{2}`, `\ln(x)`, `\log_{b}(x)`.
  - Notes: translated to the same AST as ASCII; whitespace ignored.

- Disambiguation rules
  - `log(x)` defaults to natural log unless author specifies a base; allow `log10(x)`, `log2(x)`, or LaTeX `\log_{b}(x)`.
  - Decimal separator is `.`; thousands separators are not allowed.
  - Whitespace is ignored; Unicode superscripts are not required for input.

- Examples
  - Accept: `2(x+3)`, `2x+6`, `sqrt(2)/2`, `1.23e-4`, `|x-2|`, `9.8 m/s^2`, `\frac{1}{2}`, `\sqrt{x}`.
  - Reject: `2^^3` (invalid operator), `1,000` (thousands separator), `tan x` (missing parentheses if not supported), `9.8 mph` when units are restricted to SI.

## MVP (Phase 1)

### Numeric Equivalence

- FR-001: Evaluate numeric answers using absolute tolerance with author-configurable value.
  - Example
    - Author config: `expected: 5.0`, `tolerance: {abs: 0.1}`
    - Student ✓: `5.08`, `4.92`  • Student ✗: `4.89`, `5.21`
- FR-002: Evaluate numeric answers using relative tolerance with author-configurable value; relative error computed against max(|reference|, epsilon) for stability.
  - Example
    - Author config: `expected: 100`, `tolerance: {rel: 1%}`
    - Student ✓: `99.2` (0.8%), `101.0` (1.0%)  • Student ✗: `101.2` (1.2%)
- FR-003: Treat numerically equivalent representations (e.g., scientific notation variants) as equal when form constraints do not forbid them.
  - Example
    - Author config: `expected: 6e7`, `form: none`
    - Student ✓: `60e6`, `60000000`
    - Student ✗: `6e7` with `form: integer-only` (fails form rule even though value matches)
- FR-004: Support decimal-precision validation independent of tolerance; numeric value is re-parsed to verify precision rules.
  - Example
    - Author config: `expected: 0.8`, `form: decimal`, `precision: exactly 2`
    - Student ✓: `0.80`  • Student ✗: `0.8`, `0.800`



### Algebraic Equivalence

- FR-005: Parse student and reference expressions into an AST for algebraic evaluation.
  - Example
    - Author config: `expected: 2(x+3)`, `equivalence: algebraic`
    - Student ✓: `2x + 6`
    - Student ✗: `2**` (syntax error → parsing fails)
- FR-006: Normalize expressions (e.g., whitespace removal, constant folding, commutative reordering, safe factor/expand) prior to comparison.
  - Example
    - Author config: `expected: 2x + 6`
    - Student ✓: `  x*2+   6  `, `2(x+3)` (after safe expand)
    - Student ✗: `2(x+3) + 1`
- FR-007: Determine algebraic equivalence by evaluating both expressions at N random points (default N≈8) within allowed variable domains; all samples must match within tolerance to pass.
  - Example
    - Author config: `expected: 2(x+3)`, `N: 8`, `tolerance: {abs: 1e-6}`
    - Student ✓: `2x + 6`
    - Student ✗: `x(x+2)` (matches for some x, fails others → not equivalent)
- FR-008: Enforce domain guards before equivalence checks; reject invalid evaluations (e.g., division by zero, invalid roots/logs) and emit targeted feedback.
  - Example
    - Author config: `expected: (x^2-1)/(x-1)`, `domain: x ≠ 1`
    - Student ✓: `(x+1)` with `domain: x ≠ 1` respected
    - Student ✗: `(x+1)` with domain unset and sample at `x=1` → feedback `domain_violation`
- FR-009: Allow authors to specify the set of allowed variables per input.
  - Example
    - Author config: `allowed_variables: [x, y]`
    - Student ✓: `2x + 3`  • Student ✗: `2z + 3` (z not permitted)
- FR-010: Allow authors to define variable domains for sampling (ranges, exclusions, integer-only, etc.).
  - Example
    - Author config: `x ∈ [-5,5], integers only; exclude 0`
    - Student ✓: `2/(x-1)` (sampling avoids `x=1` if excluded)  • Student ✗: `2/x` if 0 not excluded and sample hits `x=0` → `domain_violation`
- FR-011: Ensure deterministic results by supporting seeded random number generation for sampling and implementing the evaluator as a pure function.
  - Example
    - Author config: `ctx.seed: 12345`, `N: 8`
    - Student ✓: repeated submissions of `2x+6` vs `2(x+3)` → identical pass/fail and details
- FR-012: Enforce exact-form requirements when configured: integer-only, fraction (rational) only, simplified fraction, or decimal with precision rules (exactly/at least/at most N places).
  - Example (integer-only)
    - Author config: `expected: 7`, `form: integer`
    - Student ✓: `7`  • Student ✗: `7/1`, `7.0`
  - Example (simplified fraction)
    - Author config: `expected: 4/5`, `form: simplified_fraction`
    - Student ✓: `4/5`  • Student ✗: `8/10`, `0.8`


### Units

- FR-013: Support optional unit handling: parse unit tokens, normalize to canonical (e.g., SI) units, and compare values after conversion when allowed.
  - Example
    - Author config: `expected: 9.8 m/s^2`, `units: required`, `accepted: [m/s^2, cm/s^2]`
    - Student ✓: `980 cm/s^2` (auto-converts)  • Student ✗: `9.8 ft/s^2`
- FR-014: When units are enabled, provide targeted feedback for missing unit, wrong-but-convertible unit (with expected unit), and incompatible unit.
  - Example
    - Author config: `expected: 9.8 m/s^2`, `units: required`, `accepted: [m/s^2]`
    - Student ✗ (missing): `9.8` → feedback `missing_unit`
    - Student ✗ (convertible wrong): `980 cm/s^2` → feedback `wrong_unit_convertible`, suggest `m/s^2`
    - Student ✗ (incompatible): `9.8 mph` → feedback `unit_not_accepted`
- FR-015: Allow authors to require or ignore units; allow configuration of accepted units when units are required.
  - Example
    - Author config A: `units: required`, `accepted: [N]`  → Student ✓: `10 N`; Student ✗: `10`
    - Author config B: `units: ignore`  → Student ✓: `10`, `10 N` (units ignored)
