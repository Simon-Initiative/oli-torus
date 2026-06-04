# Math AST Normalization - Functional Design Document

## 1. Executive Summary
Implement Level 1 structural normalization as a shared Gleam subsystem layered after parsing and before later evaluation/equivalence logic. The design adds a separate normalized AST, deterministic debug formatting, and stable hashes while preserving the original parsed AST and source metadata. The normalizer intentionally excludes expansion, factoring, cancellation, trigonometric identities, and assumption-dependent rewrites so it cannot become an unsafe symbolic algebra layer.

The implementation lives under `gleam/src/math/` and is exposed only through `gleam/src/torus_math.gleam`. Elixir and TypeScript callers may add thin wrappers later, but normalization rules remain in Gleam so Erlang and JavaScript targets stay aligned. This design satisfies FR-001 through FR-006 and AC-001 through AC-007.

## 2. Requirements & Assumptions
- Functional requirements:
  - FR-001: Provide structural normalization for parsed math ASTs without algebraic simplification.
  - FR-002: Preserve original parsed AST and source metadata for exact-form and diagnostics work.
  - FR-003: Produce deterministic normalized debug strings and hashes.
  - FR-004: Keep normalization domain-preserving and non-simplifying.
  - FR-005: Support shared Erlang and JavaScript target behavior.
  - FR-006: Provide focused automated coverage for normalization behavior.
- Non-functional requirements:
  - Cross-target determinism is mandatory for normalized output and hash generation.
  - Normalization must be bounded, local, and suitable for interactive grading/prototype workflows.
  - Normalization must not panic on valid parser output.
  - Debug strings, warnings, logs, and future telemetry must not expose sensitive submitted-answer data beyond controlled developer/prototype contexts.
- Assumptions:
  - Existing parser output from `math/ast.gleam` is the input contract for this work.
  - This feature does not add database storage, production runtime telemetry, or learner-facing UI.
  - The MVP exposes structural normalization only. Future polynomial, rational, or heuristic simplification passes require separate contracts.
  - Exact-form constraints will inspect preserved parser metadata rather than deriving source form from the normalized AST.

## 3. Repository Context Summary
- What we know:
  - `gleam/src/math/ast.gleam` owns `Parsed`, `Expr`, `ExprKind`, `NumberLiteral`, spans, notation metadata, and multiplication-style metadata.
  - `gleam/src/torus_math.gleam` is the public Gleam API boundary and already exposes parse, validation, debug formatting, equality config JSON, and equality evaluation functions.
  - `gleam/src/math/format.gleam` provides parser debug strings for demos and golden tests; normalized debug strings should be separate so parser output and normalized output do not become coupled.
  - `lib/oli/math.ex` is a thin Elixir wrapper over generated Gleam modules.
  - `assets/src/gleam/torusExpression.ts` and `assets/src/gleam/torusEquality.ts` are thin browser wrappers over generated Gleam JavaScript.
  - Gleam code must pass `gleam test --target erlang` and `gleam test --target javascript`.
- Unknowns to confirm:
  - Whether the MVP should expose only `structural_normalize` or also reserve `normalize_with_options` with only `Structural` enabled.
  - The numeric size limit for exact integer/rational folding across BEAM and JavaScript.
  - Whether developer-preview warnings beyond unit placeholder warnings are required in the first implementation phase.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
Add the following Gleam modules:

- `gleam/src/math/normalization/types.gleam`
  - Owns `Normalized`, `NormalExpr`, `ExactNumber`, `NormalizationWarning`, and related small helper types.
  - Keeps normalized representation separate from parser `Expr`.
- `gleam/src/math/normalization/normalize.gleam`
  - Owns the structural normalization pass.
  - Recursively normalizes parser expressions, flattens associative addition/multiplication, folds safe literal-only numeric operations, and sorts commutative operands.
- `gleam/src/math/normalization/format.gleam`
  - Owns normalized debug string formatting and stable sort-key generation.
  - Must not depend on target-specific inspect output.
- `gleam/src/math/normalization/hash.gleam`
  - Owns stable SHA-256 hash derivation from normalized debug strings using `gleam_crypto`'s `gleam/crypto.hash(crypto.Sha256, data)`.
  - Encodes the digest as a stable lowercase hexadecimal string so Erlang and JavaScript callers receive the same text contract.

Expose through `gleam/src/torus_math.gleam`:

```gleam
pub fn structural_normalize(parsed: ast.Parsed) -> normalization_types.Normalized

pub fn normalized_to_debug_string(
  normalized: normalization_types.Normalized,
) -> String
```

```gleam
pub fn normalized_hash(normalized: normalization_types.Normalized) -> String
```

This addresses AC-006 by keeping Torus callers on the public `torus_math` boundary and avoiding duplicated normalization rules in wrappers.

### 4.2 State & Data Flow
Data flow:

1. Caller parses input with `torus_math.parse`.
2. Caller passes successful `ast.Parsed` to `torus_math.structural_normalize`.
3. The normalizer converts `ast.Expression(expr)` into `Normalized(original: expr, normal: normal_expr, warnings: warnings)`.
4. The normalizer preserves source metadata by retaining the original parser expression and by copying spans or source references into normalized nodes where useful.
5. Debug formatting reads only the normalized AST and emits deterministic strings for comparison, golden tests, and hashing.

`ast.Quantity` remains reserved for future unit work. The MVP result type should include unit-specific normalized result shapes now, but the implementation should preserve unit expressions structurally and emit a developer warning that semantic unit normalization is unsupported. It should not invent unit algebra, conversions, or dimensional analysis.

### 4.3 Lifecycle & Ownership
- The parser owns syntax and source metadata.
- The normalizer owns stable structural representation.
- Later evaluator/equivalence layers own numeric sampling and correctness decisions.
- Exact-form validation owns checks against original source representation.
- Elixir and TypeScript wrappers own runtime adaptation only, not math behavior.

This lifecycle keeps FR-001 and FR-004 separate: structural normalization can make cheap shape-stability improvements without deciding broader algebraic equivalence.

### 4.4 Alternatives Considered
- Reuse the parser AST as the normalized AST:
  - Rejected. Mutating or reusing `Expr` would blur parser source representation with semantic shape and would make metadata preservation harder to reason about. A separate `NormalExpr` directly supports FR-002 and AC-003.
- Expose `normalize_with_options` immediately:
  - Deferred. Multiple levels invite premature use of polynomial or rational behavior. The MVP should expose `structural_normalize`; options can be added when a second normalization level exists.
- Use target-specific hash functions in Elixir and TypeScript:
  - Rejected for this milestone. Target-specific hashing risks BEAM/browser drift and violates FR-005. Use `gleam_crypto` SHA-256 in Gleam and expose the resulting string through `torus_math`.
- Implement polynomial-lite collection now:
  - Rejected. Like-term collection crosses toward simplification and is not necessary for AC-001 or AC-002.

## 5. Interfaces
- Public Gleam API:
  - `torus_math.structural_normalize(parsed: ast.Parsed) -> Normalized`
  - `torus_math.normalized_to_debug_string(normalized: Normalized) -> String`
  - `torus_math.normalized_hash(normalized: Normalized) -> String`
- Internal normalized result shape:

```gleam
pub type Normalized {
  Normalized(
    original: ast.Parsed,
    normal: NormalParsed,
    warnings: List(NormalizationWarning),
  )
}

pub type NormalParsed {
  NormalExpression(NormalExpr)
  NormalQuantity(value: NormalExpr, unit: NormalUnitExpr)
}

pub type NormalUnitExpr {
  NUnitAtom(symbol: String, span: ast.Span)
  NUnitProduct(List(NormalUnitExpr), span: ast.Span)
  NUnitQuotient(numerator: NormalUnitExpr, denominator: NormalUnitExpr, span: ast.Span)
  NUnitPower(unit: NormalUnitExpr, exponent: Int, span: ast.Span)
  NUnitUnsupported(original: ast.UnitExpr)
}

pub type NormalExpr {
  NNumber(ExactNumber, source: ast.NumberLiteral, span: ast.Span)
  NVariable(String, span: ast.Span)
  NConstant(ast.Constant, span: ast.Span)
  NSum(List(NormalExpr), span: ast.Span)
  NProduct(List(NormalExpr), span: ast.Span)
  NPower(base: NormalExpr, exponent: NormalExpr, span: ast.Span)
  NCall(name: ast.FunctionName, args: List(NormalExpr), span: ast.Span)
  NAbs(NormalExpr, span: ast.Span)
  NFactorial(NormalExpr, span: ast.Span)
  NNegate(NormalExpr, span: ast.Span)
  NDivide(left: NormalExpr, right: NormalExpr, span: ast.Span)
}
```

`NNegate` and `NDivide` are intentionally retained instead of rewriting all subtraction/division into multiplication by negative values or reciprocal powers. That preserves domain-sensitive structure and avoids unsafe simplification for FR-004 and AC-005.

Exact number representation:

```gleam
pub type ExactNumber {
  ExactInteger(Int)
  ExactRational(numerator: Int, denominator: Int)
  ExactDecimal(raw: String, numerator: Int, denominator: Int)
  ApproximateFloat(raw: String, value: Float)
  LargeNumber(raw: String)
}
```

The implementation should start conservatively. If exact rational folding cannot be made cross-target safe for a value, use `LargeNumber(raw)` or `ApproximateFloat(raw, value)` and preserve the literal source. This supports AC-003 and mitigates cross-target numeric drift.

Warnings:

```gleam
pub type NormalizationWarning {
  LargeExactNumberKeptAsString(span: ast.Span)
  DomainSensitiveRewriteSkipped(span: ast.Span)
  UnitSemanticNormalizationUnsupported
}
```

Warnings are developer/prototype diagnostics only in this milestone. `UnitSemanticNormalizationUnsupported` is emitted when normalizing `ast.Quantity`; it records that unit-specific result types exist, but unit semantics are not yet supported.

Hashing:

```gleam
pub fn normalized_hash(normalized: Normalized) -> String {
  normalized
  |> normalized_to_debug_string
  |> utf8_bit_array
  |> crypto.hash(crypto.Sha256)
  |> bit_array_to_lower_hex
}
```

The actual implementation may use helper names that fit the codebase, but the contract is SHA-256 over the normalized debug string, returned as lowercase hex. `Md5` and `Sha1` from `gleam_crypto` must not be used because the package docs identify them as weak algorithms even though this is not a security hash.

## 6. Data Model & Storage
- No database schema changes.
- No persistent storage changes.
- No activity model or equality JSON contract changes are required for the MVP.
- The normalized AST is runtime data produced from parser output. It may later become an internal cache or diagnostic artifact, but this FDD does not store it.

## 7. Consistency & Transactions
- No Ecto transactions are introduced.
- Consistency is functional and deterministic: the same parsed input must produce the same normalized output on repeated runs and on both supported targets.
- The normalizer must avoid target-specific order, map iteration, inspect output, or floating-point formatting as part of stable sort keys.

## 8. Caching Strategy
- No application cache is required.
- Hashes and debug strings should be computed from the normalized AST when requested.
- If later runtime grading needs caching, cache by normalized debug string or hash at that later boundary, not inside the MVP normalizer.

## 9. Performance & Scalability Posture
- The normalization pass should be a bounded recursive tree transform.
- Associative flattening should be linear in the number of flattened operands.
- Commutative operand sorting should be `O(n log n)` per sum/product node, where `n` is the number of flattened operands.
- Stable sort keys should be computed once per child during a sort pass rather than regenerated repeatedly in comparison callbacks.
- No unbounded algebraic search, expansion, factoring, cancellation, or identity rewriting is allowed.
- Very large exact numeric literals should not trigger expensive arbitrary-precision work in this milestone.

## 10. Failure Modes & Resilience
- Valid parser output should always normalize without panics.
- Unit expressions should normalize into unit-specific placeholder result types and emit `UnitSemanticNormalizationUnsupported` rather than guessing at conversions, cancellation, or dimensional equivalence.
- Large numeric values that cannot be safely folded across targets should remain as source-preserving values with warnings instead of overflowing or drifting.
- Domain-sensitive rewrites should be skipped rather than partially applied.
- Hash generation should use SHA-256 from `gleam_crypto`. If dependency installation or target support blocks that implementation, the blocker should be resolved in planning rather than silently replacing the algorithm in Elixir or TypeScript.

## 11. Observability
- No production telemetry is required for this feature.
- Tests and prototype surfaces should use normalized debug strings as the main observability aid.
- If future prototype UI exposes warnings, it should display warning categories and spans rather than logging full answer text.
- AppSignal or application telemetry should not be added until normalization is used in a production runtime path.

## 12. Security & Privacy
- The normalizer is pure code over already-parsed expressions and should not introduce authorization or persistence concerns.
- Do not log submitted expressions from normalization internals.
- Warnings and debug strings are developer/test/prototype artifacts. Any future learner-facing use must be reviewed for privacy and copy quality.
- Public diagnostics must avoid exposing hidden expected answers or author configuration details.

## 13. Testing Strategy
- Add Gleam tests under `gleam/test/`, likely `math_normalization_test.gleam`.
- Structural equivalence tests for AC-001:
  - `x + 2` and `2 + x`
  - `x * 2`, `2x`, and `2 * x`
  - `(x + y) + z` and `x + (z + y)`
  - `2 * 3 * x` and `6x`
- Literal folding tests for AC-002:
  - `2 + 3` normalizes to a numeric sum result.
  - `2 * 3 * x` normalizes with numeric coefficient first.
  - `2(x + 3)` and `2x + 6` remain structurally distinct.
- Metadata preservation tests for AC-003:
  - `0.80` versus `0.8`
  - `8/10` versus `4/5`
  - `1.2e-3` versus `0.0012`
  - `2x` versus `2*x`
- Determinism tests for AC-004:
  - Assert stable normalized debug strings and hashes across repeated runs.
  - Assert SHA-256 normalized hashes are lowercase hex strings and are computed from normalized debug strings.
  - Run the same suite with `gleam test --target erlang` and `gleam test --target javascript`.
- Domain preservation tests for AC-005:
  - `x/x` does not normalize to `1`.
  - `(x^2 - 1)/(x - 1)` does not normalize to `x + 1`.
  - `0 * (1 / (x - x))` does not normalize to `0`.
  - `sqrt(x^2)` does not normalize to `x`.
  - `sin(x)^2 + cos(x)^2` does not normalize to `1`.
- Public boundary tests for AC-006:
  - Call normalization only through `torus_math` in at least one public API test.
- Coverage completeness for AC-007:
  - Ensure the final test corpus includes positive structural-equivalence, Level 1 non-equivalence, metadata preservation, and cross-target determinism cases.

Required gates:

```bash
cd gleam && gleam format --check src test
cd gleam && gleam test --target erlang
cd gleam && gleam test --target javascript
```

## 14. Backwards Compatibility
- Existing parser APIs remain unchanged.
- Existing equality APIs remain unchanged.
- Existing Elixir and TypeScript wrappers remain compatible unless a later phase chooses to expose normalization there.
- Existing parser debug strings from `math/format.gleam` should not change. Normalized debug strings are a new, separate output.

## 15. Risks & Mitigations
- Risk: the normalizer starts simplifying expressions beyond Level 1.
  - Mitigation: retain division/negation/domain-sensitive structures and add explicit non-equivalence tests for unsafe rewrites.
- Risk: exact numeric folding behaves differently on JavaScript and BEAM.
  - Mitigation: use conservative numeric bounds, preserve raw literals, and test both targets.
- Risk: source metadata is lost when producing normalized nodes.
  - Mitigation: store the original parsed AST in `Normalized` and keep source literals/spans on relevant normalized nodes.
- Risk: public API overcommits to future normalization levels.
  - Mitigation: expose only `structural_normalize` in the MVP.
- Risk: sorting depends on runtime-specific representation.
  - Mitigation: sort only by explicit normalized node rank plus stable normalized debug string.

## 16. Open Questions & Follow-ups
- Define the exact safe integer/rational folding bounds for cross-target stability.
- Decide whether additional developer-preview warnings beyond `UnitSemanticNormalizationUnsupported` are needed in the first implementation phase.
- Consider a later developer prototype update to display normalized debug strings and warnings.
- Future work should define separate FDDs for `collect_like_terms`, polynomial normal form, and rational normal form with guards.

## 17. References
- `docs/exec-plans/current/epics/math/normalization/prd.md`
- `docs/exec-plans/current/epics/math/normalization/requirements.yml`
- `docs/exec-plans/current/epics/math/normalization/math-normalization-design.md`
- `https://hexdocs.pm/gleam_crypto/gleam/crypto.html`
- `gleam/src/math/ast.gleam`
- `gleam/src/torus_math.gleam`
- `gleam/src/math/format.gleam`
- `docs/STACK.md`
- `docs/TOOLING.md`
- `docs/TESTING.md`
- `docs/BACKEND.md`
- `docs/FRONTEND.md`
- `docs/CODEREVIEW.md`
