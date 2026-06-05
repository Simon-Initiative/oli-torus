# Native Gleam Math Parser - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/math/parser/prd.md`
- FDD: `docs/exec-plans/current/epics/math/parser/fdd.md`
- Requirements: `docs/exec-plans/current/epics/math/parser/requirements.yml`

## Scope
Deliver the first parser milestone for a Torus-owned ASCII math syntax layer in pure Gleam. The plan covers AST and error contracts, tokenization, Pratt parsing, full MVP operator/function syntax from `informal.md`, validation separation, stable debug formatting, and server/browser boundary updates needed to consume the public parser module.

Guardrails:
- Keep parser, validation, formatting, normalization, evaluation, unit handling, JSON serialization, production UI, and grading integration separate.
- Do not introduce database storage, migrations, caching, background jobs, production telemetry emission, or feature flags.
- Do not duplicate parser behavior in Elixir or TypeScript; Torus callers must go through the public Gleam API and thin wrappers.
- Preserve privacy by avoiding production logs or telemetry that include raw learner expressions.
- In phases that write Gleam code, use liberal function-level and code-level comments to explain why a function, branch, binding-power choice, metadata field, or error path exists. Comments should capture parser intent and ambiguity decisions, not restate obvious syntax.

## Clarifications & Default Assumptions
- `gleam/src/expression.gleam` may remain temporarily as a compatibility shim, but new parser implementation should live behind `gleam/src/torus_math.gleam`. The public module cannot be `math.gleam` because it collides with Erlang's standard `math` module on the BEAM target.
- Browser-facing JSON serialization is deferred unless a follow-up UI slice requires it.
- Units are deferred, but lexer token metadata must preserve whitespace boundaries for the later unit milestone.
- The first production consumer is not selected yet, so this plan stops at parser boundary integration and developer smoke checks.
- Jira tracking is available for execution, but no Jira issue was provided with the work item.

## Phase 1: Parser Contracts And Cross-Target Test Harness
- Goal: Establish the public type contracts, module layout, and shared test corpus skeleton before parser behavior is implemented.
- Tasks:
  - [ ] Create `gleam/src/torus_math.gleam` as the public parser API boundary.
  - [ ] Create `gleam/src/math/ast.gleam` with `Parsed`, `Expr`, `ExprKind`, number literal metadata, operators, constants, function names, spans, parse errors, parse config, and validation error/config types.
  - [ ] Create `gleam/src/math/token.gleam` with number, word, symbol tokens, spans, and `leading_space`.
  - [ ] Decide whether `gleam/src/expression.gleam` delegates to `torus_math.gleam` for compatibility or is removed with caller updates in a later phase.
  - [ ] Add initial empty or minimal test modules for lexer, parser, precedence, validation, and formatting.
  - [ ] Add function-level and code-level Gleam comments that explain why public types, metadata fields, and compatibility boundaries exist.
- Testing Tasks:
  - [ ] Verify the type skeleton compiles on both targets. Covers AC-001.
  - [ ] Add a minimal golden corpus fixture structure that can be reused by later parser tests. Supports AC-002, AC-003, AC-004, and AC-006.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Public and internal module boundaries exist.
  - Types compile on both Gleam targets.
  - Test modules are in place and ready for behavior coverage.
- Gate:
  - Both target test commands pass before lexer implementation begins.
- Dependencies:
  - PRD, FDD, and `requirements.yml` are present.
- Parallelizable Work:
  - Test fixture shape and debug-output expectations can be drafted while AST and token types are implemented.

## Phase 2: Lexer And Number Literal Semantics
- Goal: Convert input strings into spanned tokens with strict number handling and whitespace metadata.
- Tasks:
  - [ ] Implement `gleam/src/math/lexer.gleam` to walk UTF codepoints once and emit tokens in source order.
  - [ ] Implement strict numeric literal scanning for integers, decimals with digits on both sides of `.`, and scientific notation using `e` or `E`.
  - [ ] Compute and preserve raw numeric string, parsed float value, notation, and mantissa decimal-place metadata.
  - [ ] Emit word tokens for alphabetic runs and symbol tokens for `+`, `-`, `*`, `/`, `^`, `(`, `)`, `|`, `!`, and comma.
  - [ ] Reject unsupported characters such as `²` and unsupported separators such as `,` with structured spans.
  - [ ] Preserve `leading_space` on every token for future unit parsing.
  - [ ] Add function-level and code-level Gleam comments explaining why strict number forms, UTF codepoint handling, unsupported-character paths, and `leading_space` are implemented this way.
- Testing Tasks:
  - [ ] Add lexer tests for accepted number forms, word runs, symbols, spans, and leading whitespace. Covers AC-004.
  - [ ] Add lexer rejection tests for `.5`, `1.`, `1e`, `1e+`, `1,000`, and unsupported Unicode. Covers AC-003.
  - [ ] Run both target test suites to verify lexer behavior is portable. Covers AC-001.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Lexer emits deterministic token streams and structured lexical errors.
  - Numeric metadata and whitespace metadata are covered by tests.
- Gate:
  - Lexer tests pass on both targets before parser implementation begins.
- Dependencies:
  - Phase 1 types and test harness.
- Parallelizable Work:
  - Rejection corpus cases can be added while accepted token cases are implemented.

## Phase 3: Pratt Parser Core And Precedence
- Goal: Implement the core expression parser for numbers, variables, constants, grouping, explicit operators, unary signs, and precedence.
- Tasks:
  - [ ] Implement parser state and `parse_expr` Pratt loop in `gleam/src/math/parser.gleam`.
  - [ ] Parse numeric literals, single-letter variables, reserved constants `pi` and `e`, and parenthesized expressions.
  - [ ] Implement explicit binary operators `+`, `-`, `*`, `/`, and `^`.
  - [ ] Implement unary prefix `+` and `-`.
  - [ ] Encode precedence and associativity: add/subtract left, multiply/divide left, unary prefix lower than power and higher than multiplication, power right-associative.
  - [ ] Ensure parser rejects trailing input, malformed operator sequences, unclosed parentheses, and incomplete expressions with structured errors.
  - [ ] Add function-level and code-level Gleam comments explaining why Pratt binding powers, associativity choices, delimiter handling, and error paths are shaped as implemented.
- Testing Tasks:
  - [ ] Add parser acceptance tests for literals, variables, constants, grouping, and explicit operators. Covers AC-002.
  - [ ] Add precedence tests for `2+3*4`, `2*3+4`, `2^3^4`, `-x^2`, and `(-x)^2`. Covers AC-002.
  - [ ] Add rejection tests for `2^^3`, `(x+1`, and `2+`. Covers AC-003.
  - [ ] Run both target test suites. Covers AC-001.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Core Pratt parser produces stable ASTs for explicit expression syntax.
  - Precedence decisions from the FDD are locked by tests.
- Gate:
  - Core parser and precedence tests pass on both targets before full ASCII syntax is added.
- Dependencies:
  - Phase 2 lexer behavior.
- Parallelizable Work:
  - Error-format expectations can be refined while accepted parser cases are implemented.

## Phase 4: Full MVP ASCII Syntax Coverage
- Goal: Complete the proposed parser syntax list from `informal.md`.
- Tasks:
  - [ ] Implement implicit multiplication when adjacent tokens can start a primary expression.
  - [ ] Implement deterministic `1/2x -> (1/2) * x` behavior.
  - [ ] Implement function calls requiring parentheses and exactly one expression argument for `sin`, `cos`, `tan`, `ln`, `log`, `log10`, `log2`, `sqrt`, `abs`, and `exp`.
  - [ ] Reject supported function names without parentheses, including `tan x` and `sqrt 2`, with structured `FunctionRequiresParentheses` errors.
  - [ ] Implement absolute value bars as `Abs` semantics while preserving source spans.
  - [ ] Implement postfix factorial `!`.
  - [ ] Preserve explicit versus implicit multiplication style in AST nodes.
  - [ ] Add function-level and code-level Gleam comments explaining why implicit multiplication, function-parentheses enforcement, absolute-bar handling, and factorial parsing behave as specified.
- Testing Tasks:
  - [ ] Add parser acceptance tests for `2x`, `xy`, `2(x+3)`, `(x+1)(x-1)`, `2x + 6`, `sqrt(2)/2`, all supported functions, `|x-2|`, `n!`, `2x^2`, and `1/2x`. Covers AC-002 and AC-004.
  - [ ] Add rejection tests for `tan x`, `sqrt()`, `sqrt 2`, `|x-2`, and malformed implicit/operator boundaries. Covers AC-003.
  - [ ] Run both target test suites. Covers AC-001.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Full MVP syntax list is implemented and covered by accepted/rejected corpus tests.
  - Function/operator scope cannot drift without test failures.
- Gate:
  - Full corpus passes on both targets before validation and formatting are finalized.
- Dependencies:
  - Phase 3 Pratt parser core.
- Parallelizable Work:
  - Function-call tests and implicit-multiplication tests can be authored independently once the parser core exists.

## Phase 5: Validation Layer And Stable Debug Formatting
- Goal: Add the non-parser layers required for symbol validation and developer-facing golden output while keeping parser semantics pure.
- Tasks:
  - [ ] Implement `gleam/src/math/validate.gleam` for allowed variables and allowed functions.
  - [ ] Ensure validation accepts parsed AST values and does not change syntactic parse success or AST shape.
  - [ ] Implement `gleam/src/math/format.gleam` with deterministic parsed AST and parse-error debug strings.
  - [ ] Expose parse, validation, and formatting through `gleam/src/torus_math.gleam`.
  - [ ] Keep JSON serialization out of this phase unless a later plan explicitly adds a browser adapter.
  - [ ] Add function-level and code-level Gleam comments explaining why validation is separate from parsing and why debug output is deterministic but distinct from JSON serialization.
- Testing Tasks:
  - [ ] Add validation tests for allowed/disallowed variables and functions while proving syntactically valid inputs still parse. Covers AC-005.
  - [ ] Add stable debug formatting tests for representative accepted ASTs and parse errors. Covers AC-006.
  - [ ] Rerun the complete accepted/rejected corpus on both targets. Covers AC-001 through AC-006.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Parser, validation, and formatting entry points are exposed through the public module.
  - Validation and formatting are tested without coupling them to evaluator semantics.
- Gate:
  - All AC-001 through AC-006 coverage passes on both targets before Torus wrapper updates.
- Dependencies:
  - Phase 4 full parser syntax.
- Parallelizable Work:
  - Formatting tests can be developed alongside validation tests after AST shape stabilizes.

## Phase 6: Torus Boundary Integration And Build Verification
- Goal: Update the Elixir and browser boundaries to consume the public parser module without duplicating parser behavior.
- Tasks:
  - [ ] Update `lib/oli/math.ex` to call the public Gleam `torus_math` module and map result shapes intentionally.
  - [ ] Add or update focused ExUnit coverage for `Oli.Math.parse/1`, including success and structured error cases.
  - [ ] Update browser wrapper imports under `assets/src/gleam/` if the compiled JavaScript module changes from `expression.mjs` to `torus_math.mjs`.
  - [ ] Update developer-only math prototype usage if needed to display server and browser parser/debug output.
  - [ ] Keep parser core free of telemetry/logging; document any future aggregate telemetry as a follow-up.
  - [ ] Confirm no feature flag is required because no production behavior is exposed.
  - [ ] If this phase touches Gleam compatibility shims or public API modules, preserve the same liberal comment standard explaining why compatibility, result mapping, or module naming decisions exist.
- Testing Tasks:
  - [ ] Run Gleam cross-target tests after integration changes. Covers AC-001 through AC-006.
  - [ ] Run targeted Elixir tests for `Oli.Math` boundary behavior.
  - [ ] Run frontend type/build checks affected by the browser wrapper, noting any pre-existing unrelated failures separately.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
  - Command(s): `mix test <targeted_math_test_file>`
  - Command(s): `cd assets && yarn run check-types`
- Definition of Done:
  - Torus server and browser wrappers consume the public parser boundary.
  - No production UI, storage, or grading behavior changes are introduced.
  - Any remaining dev prototype behavior uses public parser APIs only.
- Gate:
  - Parser tests, targeted Elixir tests, and relevant frontend checks are run before review.
- Dependencies:
  - Phase 5 public parser API.
- Parallelizable Work:
  - Elixir boundary tests and browser wrapper updates can proceed in parallel after public compiled module names stabilize.

## Phase 7: Final Review, Documentation, And Release Readiness
- Goal: Close the work item with complete verification evidence, review coverage, and follow-up decisions.
- Tasks:
  - [ ] Update work item docs if implementation decisions differ from PRD/FDD/plan assumptions.
  - [ ] Capture commands run and outcomes in the implementation summary or PR description.
  - [ ] Confirm no raw-expression logging or production telemetry was added.
  - [ ] Confirm no feature flag, migration, cache, background job, or persisted data change was introduced.
  - [ ] Prepare follow-up notes for JSON serialization, unit parsing, evaluator work, and first production consumer selection.
  - [ ] Run code review with security and performance lenses; include Elixir and TypeScript lenses if boundary files changed.
- Testing Tasks:
  - [ ] Run final cross-target parser tests. Covers AC-001 through AC-006.
  - [ ] Run final targeted Torus integration tests changed by Phase 6.
  - [ ] Run formatting checks for changed Elixir and TypeScript files where applicable.
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
  - Command(s): `mix format <changed_elixir_files> --check-formatted`
  - Command(s): `cd assets && yarn run check-types`
- Definition of Done:
  - Verification commands and any known unrelated failures are documented.
  - Review scope is explicit and matches changed files.
  - Follow-up work is separated from parser milestone completion.
- Gate:
  - Work is ready for PR review only after cross-target parser tests and targeted integration checks have been run.
- Dependencies:
  - Phase 6 integration and verification.
- Parallelizable Work:
  - Documentation reconciliation and review-prep notes can happen while final command runs are executing.

## Parallelization Notes
- Phase 1 type design and test fixture scaffolding can be split between one owner for AST/error contracts and one owner for corpus/test helpers.
- Phase 2 lexer acceptance and rejection tests can be authored in parallel with lexer implementation once token types are stable.
- Phase 4 function-call coverage and implicit-multiplication coverage are separable after the Pratt parser core lands.
- Phase 5 validation and debug formatting can proceed in parallel after AST shape is stable.
  - Phase 6 Elixir and browser boundary updates can proceed in parallel once `torus_math.gleam` and compiled module names are stable.
- Do not parallelize edits to the same Gleam parser modules without explicit ownership, because parser precedence and AST construction are tightly coupled.

## Phase Gate Summary
- Gate A: PRD, FDD, requirements, and plan traceability are valid.
- Gate B: Phase 1 type contracts compile under `gleam test --target erlang` and `gleam test --target javascript`.
- Gate C: Lexer tests pass on both targets with numeric metadata and `leading_space` coverage.
- Gate D: Core Pratt parser and precedence tests pass on both targets.
- Gate E: Full MVP ASCII syntax corpus passes on both targets.
- Gate F: Validation and debug formatting tests satisfy AC-005 and AC-006 without coupling to evaluation.
- Gate G: `Oli.Math` and browser wrappers consume the public parser boundary and targeted integration checks are run.
- Gate H: Final review confirms security, performance, privacy, and test evidence before implementation is considered complete.
