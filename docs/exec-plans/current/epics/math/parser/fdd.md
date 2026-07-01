# Native Gleam Math Parser - Functional Design Document

## 1. Executive Summary
Build the math parser as a pure Gleam subsystem under `gleam/src/math*`, exposed through a small public `torus_math` module and wrapped by Torus integration points only at the Elixir and browser boundaries. The parser will use a lexer plus Pratt parser to produce Torus-owned AST values and structured parse errors for the proposed ASCII math syntax. The same parser source and golden corpus must pass on Erlang/BEAM and JavaScript targets, satisfying AC-001 through AC-006.

This design keeps the parser focused on syntactic validity. Author-specific validation, normalization, evaluation, unit handling, JSON serialization, production UI, and grading integration remain separate follow-up layers.

## 2. Requirements & Assumptions
- Functional requirements:
  - Provide a shared pure Gleam parser contract that builds for BEAM and JavaScript without target-specific parser externals. Supports FR-001 and AC-001.
  - Produce stable Torus-owned ASTs for the proposed ASCII expression subset. Supports FR-002 and AC-002.
  - Reject malformed or unsupported input with structured errors and source spans. Supports FR-003 and AC-003.
  - Preserve spans, raw number form, number notation, whitespace boundary information, and multiplication style. Supports FR-004 and AC-004.
  - Keep syntactic parsing separate from author-configuration validation. Supports FR-005 and AC-005.
  - Provide deterministic debug formatting for demos and golden tests. Supports FR-006 and AC-006.
- Non-functional requirements:
  - Parser behavior must be deterministic across Gleam Erlang and JavaScript targets.
  - Core parser modules must remain pure and must not depend on Phoenix, Ecto, DOM APIs, Node-only APIs, or JavaScript-only externals.
  - The parser must be small enough to reason about and covered by a cross-target corpus before downstream evaluation work begins.
  - Parser diagnostics must not require logging or storing raw learner expressions in production.
- Assumptions:
  - The top-level `gleam/` project is the durable home for the shared parser.
  - The current `gleam/src/expression.gleam` proof-of-concept can be replaced or redirected to the new `torus_math` public API.
  - The first milestone is a parser proof of concept, not a production learner-facing feature.
  - Unit parsing remains deferred, but token metadata must preserve enough information to support the later unit milestone.

## 3. Repository Context Summary
- What we know:
  - Torus is a Phoenix application with Elixir domain boundaries under `lib/oli/` and browser assets under `assets/src/`.
  - A top-level `gleam/` project already exists with default Erlang target and JavaScript build support.
  - `lib/oli/math.ex` currently acts as a thin Elixir boundary around the Gleam proof-of-concept parser.
  - Browser integration consumes compiled Gleam JavaScript from `gleam/build/dev/javascript` through webpack aliases and TypeScript wrappers.
  - The parser does not need database storage, publication-model integration, or LMS integration in this milestone.
- Unknowns to confirm:
  - Whether the existing `expression` module name should remain as a compatibility shim or be fully replaced by public `torus_math`.
  - Whether the next browser-facing slice needs a JSON adapter or can use debug strings until UI requirements exist.
  - Which future math activity or evaluation workflow will first consume parsed AST values.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
The parser subsystem will use these Gleam modules:

- `gleam/src/torus_math.gleam`: public API. Exposes parser, validation, and debug formatting entry points while hiding lexer/parser internals. The module is not named `math.gleam` because that compiles to Erlang module `math` and collides with Erlang's standard library on the BEAM target.
- `gleam/src/math/ast.gleam`: Torus-owned AST, number literal, operator, function, span, parse config, validation config, and error types.
- `gleam/src/math/token.gleam`: token and symbol definitions plus small token/span helpers.
- `gleam/src/math/lexer.gleam`: converts input strings into spanned tokens with `leading_space` metadata.
- `gleam/src/math/parser.gleam`: Pratt parser over tokens, including explicit operators, unary signs, postfix factorial, implicit multiplication, function calls, grouping, and absolute value bars.
- `gleam/src/math/validate.gleam`: first validation layer for author-configurable symbols and allowed functions.
- `gleam/src/math/format.gleam`: deterministic debug output for demos and golden tests.
- `gleam/src/math/unit.gleam`: deferred placeholder or later milestone module for unit syntax. It should not be implemented in the parser milestone unless a later plan explicitly adds it.

Torus integration stays outside parser internals:

- `lib/oli/math.ex` calls the public Gleam `torus_math` API and maps Gleam result shapes into Elixir terms.
- `assets/src/gleam/torusExpression.ts` or its successor imports the compiled public `torus_math.mjs` module for browser experiments.
- Developer-only LiveView or console prototypes may call these public boundaries for manual comparison.

### 4.2 State & Data Flow
Parsing is a pure in-memory transformation:

1. Caller passes an input string to the public parse API.
2. Lexer walks UTF codepoints, rejects unsupported characters, and emits tokens with spans and whitespace metadata.
3. Pratt parser consumes tokens into an AST with explicit precedence and associativity rules.
4. Parser verifies there is no trailing unsupported input.
5. Caller receives either `Ok(Parsed)` or `Error(ParseError)`.
6. Optional validation receives `Parsed` plus a symbol/function config and returns either the same parsed value or `ValidationError`.
7. Optional debug formatting receives `Parsed` or `ParseError` and returns deterministic strings for tests and demos.

No parser state is persisted. Parser state is owned by the current call stack and discarded after each parse.

### 4.3 Lifecycle & Ownership
The Gleam parser is owned as shared domain infrastructure for future math workflows. It is versioned with the Torus application, built by the existing Gleam build path, and verified by target-specific Gleam tests.

The public `torus_math` API is the stability boundary. Internal lexer/parser modules can evolve as long as public AST, error, validation, and debug-output contracts remain intentionally changed and covered by tests.

### 4.4 Alternatives Considered
- Keep separate Elixir and TypeScript parsers: rejected because it would invite server/browser behavior drift and duplicate the most error-prone logic.
- Use JavaScript-only parser code and call it from the server: rejected because Torus server-side grading and validation must not depend on browser or Node runtime behavior.
- Use a parser generator: deferred because the MVP grammar is small and Pratt parsing directly handles prefix, postfix, infix, right-associative power, and implicit multiplication with less toolchain complexity.
- Implement evaluation with parsing: rejected because parser correctness should be proven before math semantics, tolerance, unit conversion, or grading behavior is layered on top.

## 5. Interfaces
- Public parse interface:
  - `parse(input: String) -> Result(Parsed, ParseError)`
  - Accepts calculator-style ASCII math input and returns syntactic success or structured parse failure.
- Optional config-aware parse interface:
  - `parse_with_config(input: String, config: ParseConfig) -> Result(Parsed, ParseError)`
  - Reserved for grammar-level toggles only, not author-specific allowed-symbol rules.
- Public validation interface:
  - `validate_symbols(parsed: Parsed, config: SymbolConfig) -> Result(Parsed, ValidationError)`
  - Checks allowed variables and functions without changing parse behavior.
- Public formatting interface:
  - `to_debug_string(parsed: Parsed) -> String`
  - `parse_error_to_debug_string(error: ParseError) -> String`
  - Provides deterministic output for cross-target tests and developer demos.
- Supported expression syntax:
  - Number forms: integers, decimals with digits on both sides of `.`, and scientific notation using `e` or `E` with optional exponent sign.
  - Constants: `pi`, `e`.
  - Variables: single-letter variables, with alphabetic runs other than reserved names interpreted as implicit multiplication of single-letter variables.
  - Binary operators: `+`, `-`, `*`, `/`, `^`.
  - Prefix operators: unary `+`, unary `-`.
  - Postfix operator: factorial `!`.
  - Grouping: `(` and `)`.
  - Absolute value bars: `|expression|`, represented as the same function semantics as `abs(expression)` unless a later formatter needs a source-form distinction.
  - Function calls requiring parentheses and exactly one expression argument: `sin`, `cos`, `tan`, `ln`, `log`, `log10`, `log2`, `sqrt`, `abs`, `exp`.
  - Implicit multiplication forms: adjacent primary expressions such as `2x`, `2(x+1)`, `xy`, `(x+1)(x-1)`, and `2sqrt(2)`.
- Explicitly rejected MVP syntax:
  - Thousands separators such as `1,000`.
  - Decimal shorthand such as `.5` and `1.`.
  - Incomplete scientific notation such as `1e` and `1e+`.
  - Function names without parenthesized arguments such as `tan x` and `sqrt 2`.
  - Empty function calls such as `sqrt()`.
  - Unclosed grouping or absolute bars.
  - Malformed operator sequences such as `2^^3` and trailing operators such as `2+`.

## 6. Data Model & Storage
- No database schema, migrations, or persisted storage are required.
- Core AST types:
  - `Parsed`: initially `Expression(Expr)`, with `Quantity(value, unit)` reserved for the later unit milestone.
  - `Expr`: `Expr(kind: ExprKind, span: Span)`.
  - `ExprKind`: numeric literal, variable, constant, prefix expression, binary expression, function call, and factorial.
  - `NumberLiteral`: raw string, parsed float value, notation, and decimal-place count.
  - `BinaryOp`: add, subtract, explicit/implicit multiply, divide, and power.
  - `FunctionName`: `Sin`, `Cos`, `Tan`, `Ln`, `Log`, `Log10`, `Log2`, `Sqrt`, `Abs`, `Exp`.
  - `Span`: start and end source offsets.
- Token model:
  - Number, word, and symbol tokens carry spans and `leading_space`.
  - Symbols include plus, minus, star, slash, caret, left/right parenthesis, bar, bang, and comma.
- Error model:
  - Structured variants include unexpected token, unexpected end, invalid number, unsupported character, unsupported function, function requires parentheses, unclosed parenthesis, unclosed absolute value, and trailing input.
- Validation model:
  - `SymbolConfig` carries allowed variables and allowed functions.
  - `ValidationError` reports unexpected variables or disallowed functions with spans.

## 7. Consistency & Transactions
- Parsing and validation are pure functions with no transaction boundary.
- Consistency is enforced through deterministic AST/error contracts and a shared golden test corpus.
- The same corpus must run against `gleam test --target erlang` and `gleam test --target javascript`.
- Browser and server integrations must not reinterpret raw expression strings independently; they should call the public parser API.

## 8. Caching Strategy
N/A. The parser milestone should not introduce caching. If future grading paths need repeated parsing, caching should be designed near the consuming workflow with clear invalidation and privacy rules.

## 9. Performance & Scalability Posture
- Parser complexity should be linear in input size for lexing and linear in token count for Pratt parsing.
- Parser calls are expected to handle short learner or author-entered expressions, not large documents.
- Implementation should avoid repeated full-string scans beyond lexing and avoid recursive patterns that can grow unbounded for normal expression sizes.
- No production latency budget is set for this POC, but tests should include representative nested and chained expressions to catch obvious pathological behavior.

## 10. Failure Modes & Resilience
- Unsupported character: return `UnsupportedCharacter` with span and raw character. Do not silently drop characters.
- Invalid number: return `InvalidNumber` for malformed numeric literals.
- Function without required parentheses: return `FunctionRequiresParentheses`.
- Empty or malformed function argument: return an unexpected token/end error with expected expression context.
- Unclosed delimiter: return `UnclosedParenthesis` or `UnclosedAbsoluteValue`.
- Trailing input: return `TrailingInput` or an equivalent unexpected token error after a valid expression.
- Cross-target mismatch: golden tests fail; implementation must be corrected before integration proceeds.
- Browser import/build failure: webpack or TypeScript integration should fail during build rather than falling back to a separate parser.

## 11. Observability
- The parser core should not emit telemetry or logs directly.
- Developer demos should display debug strings and structured errors locally without sending raw expressions to production telemetry.
- Future product integrations may emit aggregate parse-success counts and error categories through existing AppSignal/telemetry paths, but should avoid recording raw learner input.
- Test failures and snapshot diffs are the primary observability mechanism for this parser milestone.

## 12. Security & Privacy
- Treat expression input as untrusted user input.
- Do not evaluate expressions during parsing, call dynamic code, or use runtime eval facilities.
- Do not log raw student expressions by default.
- Structured errors should carry spans and categories, not sensitive contextual data.
- Validation and parser errors should be safe to expose only after later UI formatting maps them into product language.
- No new authorization paths are introduced in this work item.

## 13. Testing Strategy
- Gleam unit and golden tests:
  - Lexer tests for strict number forms, words, symbols, spans, leading whitespace, implicit-multiplication-adjacent tokens, and unsupported characters.
  - Parser acceptance tests for integers, decimals, scientific notation, variables, constants, all supported binary/prefix/postfix operators, parentheses, implicit multiplication, all supported function calls, absolute bars, right-associative exponentiation, and unary precedence. Covers AC-002 and AC-004.
  - Parser rejection tests for malformed operators, unsupported separators, missing function parentheses, empty function calls, unclosed delimiters, and trailing operators. Covers AC-003.
  - Precedence tests for `2+3*4`, `2*3+4`, `2^3^4`, `-x^2`, `(-x)^2`, `2x^2`, and `1/2x`.
  - Validation tests for allowed/disallowed variables and functions without changing syntactic parser success. Covers AC-005.
  - Formatting tests that assert stable debug output on representative ASTs and errors. Covers AC-006.
- Cross-target gates:
  - `cd gleam && gleam test --target erlang`
  - `cd gleam && gleam test --target javascript`
  - The same accepted/rejected corpus must pass both targets. Covers AC-001.
- Integration checks:
  - Run targeted `mix test` for `Oli.Math` boundary changes.
  - Run affected `yarn` checks for browser wrapper changes when the JavaScript import path changes.
- Manual checks:
  - Use the dev math prototype or equivalent console smoke test to compare representative server and browser parse/debug output.

## 14. Backwards Compatibility
- Existing proof-of-concept callers of `Oli.Math.parse/1` should either continue to work through a compatibility wrapper or be intentionally updated to the new parsed result contract in the implementation plan.
- Existing generated JavaScript wrapper imports may need to switch from `expression.mjs` to `torus_math.mjs`; this should be treated as a known integration migration within the parser work item.
- No persisted learner, authoring, publication, or analytics data is migrated by this milestone.
- Existing course content and delivery behavior remain unchanged because the parser is not yet wired into production grading or activity behavior.

## 15. Risks & Mitigations
- Identifier ambiguity: reserve exact `pi` and `e`, require parentheses for supported function calls, and interpret other alphabetic runs as single-letter variables joined by implicit multiplication.
- Function/operator scope drift: keep the full MVP operator and function list from `informal.md` in parser acceptance tests so implementation does not accidentally support or omit syntax.
- Implicit multiplication ambiguity: document `1/2x` as `(1/2) * x` for MVP and defer ambiguity linting to validation or author tooling.
- Unary power precedence mistakes: encode `-x^2 -> -(x^2)` and `(-x)^2` as golden tests.
- Unit syntax leaking into expression parser: preserve `leading_space` but keep unit parsing out of this milestone.
- Cross-target float differences: preserve raw number literals and keep evaluator semantics out of parser tests.
- Public API instability: keep internal modules hidden and route Torus callers through `torus_math.gleam`, `Oli.Math`, and the browser wrapper.

## 16. Open Questions & Follow-ups
- Decide whether `gleam/src/expression.gleam` remains as a compatibility shim or is removed after callers move to `torus_math.gleam`.
- Decide whether browser-facing AST JSON serialization belongs in the next integration slice.
- Decide the first production consumer of the parser contract so validation and user-facing error formatting can be designed around a real workflow.
- Later unit milestone: add quantity parsing, unit validation, and unit normalization without changing the expression parser contract.
- Later evaluator milestone: add normalization, numeric evaluation, equivalence, tolerance, and feedback behavior on top of parsed ASTs.

## 17. References
- `docs/exec-plans/current/epics/math/parser/prd.md`
- `docs/exec-plans/current/epics/math/parser/requirements.yml`
- `docs/exec-plans/current/epics/math/parser/informal.md`
- `ARCHITECTURE.md`
- `docs/STACK.md`
- `docs/TOOLING.md`
- `docs/TESTING.md`
- `docs/PRODUCT_SENSE.md`
- `docs/FRONTEND.md`
- `docs/BACKEND.md`
- `docs/DESIGN.md`
- `docs/OPERATIONS.md`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
