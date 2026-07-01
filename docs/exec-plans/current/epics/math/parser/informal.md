# Informal Technical Design: Native Gleam ASCII Math Expression Parser

## Purpose

This document outlines a practical technical design for a **native Gleam math expression parser** for the new Math Evaluation feature.

The goal of the proof of concept is to demonstrate that a single Gleam implementation can parse the supported ASCII / calculator-style math syntax into a stable AST and run on both:

- BEAM / Erlang target
- JavaScript target

This parser is the foundation for later work such as client-side validation, server-side evaluation, normalization, algebraic equivalence, variable/domain validation, unit handling, and targeted feedback.

## POC thesis

The first proof of concept should prove this claim:

> A single pure Gleam parser can parse the supported ASCII math subset into a stable Torus-owned AST, and the same test suite passes on both BEAM and JavaScript.

A good first demo should show inputs like:

```text
2(x+3)
2x + 6
sqrt(2)/2
1.2e-3
|x-2|
n!
```

producing stable AST output such as:

```text
Input:
2(x+3)

AST:
Binary(
  op: Multiply(ImplicitMultiply),
  left: Num("2"),
  right: Binary(
    op: Add,
    left: Var("x"),
    right: Num("3")
  )
)
```

Units such as `9.8 m/s^2` are important for the full feature, but they should be treated as a second parser milestone after pure expression parsing is working.

## Scope of the first parser POC

The first parser POC should include:

- Integers
- Decimals
- Scientific notation, such as `1.2e-3`
- Single-letter variables, such as `x`, `y`, `t`, `a`
- Constants: `pi`, `e`
- Binary operators: `+`, `-`, `*`, `/`, `^`
- Parentheses
- Implicit multiplication:
  - `2x`
  - `2(x+1)`
  - `xy`
  - `(x+1)(x-1)`
- Function calls:
  - `sin(x)`
  - `cos(x)`
  - `tan(x)`
  - `ln(x)`
  - `log(x)`
  - `log10(x)`
  - `log2(x)`
  - `sqrt(x)`
  - `abs(x)`
  - `exp(x)`
- Absolute value bars:
  - `|x-2|`
- Factorial:
  - `n!`

The first parser POC should reject:

- `2^^3`
- `1,000`
- `tan x`
- `sqrt()`
- `(x+1`
- `|x-2`
- `2+`

## Non-goals for the first parser POC

Do not try to solve the whole evaluator in the first parser POC.

The first POC should not include:

- Algebraic equivalence
- Numeric tolerance checking
- Random sampling
- Variable domain sampling
- Unit conversion
- Targeted feedback rule matching
- Author configuration linting
- Decimal precision grading
- Significant figures
- LaTeX parsing
- MathJax or KaTeX rendering

Those features should be layered on top of the parser after the AST contract is stable.

## Recommended architecture

Use three core layers:

```text
String
  -> lexer
  -> List(Token)
  -> Pratt expression parser
  -> Parsed AST
```

Keep parsing, validation, normalization, and evaluation as separate stages:

```text
parse(input)
  -> Result(Parsed, ParseError)

validate_symbols(ast, config)
  -> Result(Parsed, ValidationError)

normalize(ast)
  -> NormalizedExpression

evaluate(ast, context)
  -> EvaluationResult
```

The core public POC function should be:

```gleam
pub fn parse(input: String) -> Result(Parsed, ParseError)
```

A configuration-aware entry point can be added early, but it should not overcomplicate the parser:

```gleam
pub fn parse_with_config(
  input: String,
  config: ParseConfig,
) -> Result(Parsed, ParseError)
```

The parser itself should answer:

> Is this syntactically valid supported math?

A later validation stage should answer:

> Is this syntactically valid math allowed by this item's author configuration?

For example, the parser may parse `2z + 3` as syntactically valid, while validation rejects it because `z` is not an allowed variable for the item.

## Directory and module layout

Use the top-level `gleam` directory and the shorter `math` module namespace.

Recommended layout:

```text
gleam/
  gleam.toml
  src/
    math.gleam
    math/
      ast.gleam
      token.gleam
      lexer.gleam
      parser.gleam
      validate.gleam
      format.gleam
      unit.gleam        # milestone 2
  test/
    math_lexer_test.gleam
    math_parser_test.gleam
    math_precedence_test.gleam
    math_units_test.gleam   # milestone 2
```

Public API:

```text
gleam/src/math.gleam
```

Internal implementation modules:

```text
gleam/src/math/ast.gleam
gleam/src/math/token.gleam
gleam/src/math/lexer.gleam
gleam/src/math/parser.gleam
gleam/src/math/validate.gleam
gleam/src/math/format.gleam
gleam/src/math/unit.gleam
```

The key point is that Torus code should depend on the public `math` API and Torus-owned AST types, not on parser implementation details.

## Suggested public API

`gleam/src/math.gleam` should expose a small API:

```gleam
pub fn parse(input: String) -> Result(Parsed, ParseError)

pub fn parse_with_config(
  input: String,
  config: ParseConfig,
) -> Result(Parsed, ParseError)

pub fn validate_symbols(
  parsed: Parsed,
  config: SymbolConfig,
) -> Result(Parsed, ValidationError)

pub fn to_debug_string(parsed: Parsed) -> String
```

For the POC, `to_debug_string` is useful for demos and golden tests.

Later, the API may grow to include:

```gleam
pub fn normalize(parsed: Parsed) -> NormalizedExpression

pub fn evaluate(
  candidate: String,
  config: EvaluationConfig,
  context: EvaluationContext,
) -> EvaluationResult
```

But that should not be part of the first parser milestone.

## AST design

Use a semantic AST, but preserve source metadata.

The AST should know what the expression means, but it should also retain enough raw source information for:

- Error highlighting
- Decimal precision rules
- Form rules
- Debug output
- Future telemetry
- Future exact-form feedback

Recommended AST shape:

```gleam
pub type Parsed {
  Expression(Expr)
  Quantity(value: Expr, unit: UnitExpr)
}

pub type Expr {
  Expr(kind: ExprKind, span: Span)
}

pub type ExprKind {
  Num(NumberLiteral)
  Var(String)
  Const(Constant)
  Prefix(op: PrefixOp, arg: Expr)
  Binary(op: BinaryOp, left: Expr, right: Expr)
  Call(name: FunctionName, args: List(Expr))
  Factorial(arg: Expr)
}

pub type NumberLiteral {
  NumberLiteral(
    raw: String,
    value: Float,
    notation: NumberNotation,
    decimal_places: Option(Int),
  )
}

pub type NumberNotation {
  IntegerNotation
  DecimalNotation
  ScientificNotation
}

pub type Constant {
  Pi
  Euler
}

pub type PrefixOp {
  Negate
  Positive
}

pub type BinaryOp {
  Add
  Subtract
  Multiply(style: MultiplyStyle)
  Divide
  Power
}

pub type MultiplyStyle {
  ExplicitMultiply
  ImplicitMultiply
}

pub type FunctionName {
  Sin
  Cos
  Tan
  Ln
  Log
  Log10
  Log2
  Sqrt
  Abs
  Exp
}

pub type Span {
  Span(start: Int, end: Int)
}
```

### Why preserve `raw` on numbers?

Do not store numeric literals as only `Float`.

Store both:

- the parsed float value
- the original raw literal

For example:

```text
0.8
0.80
8e-1
```

These may represent the same numeric value, but they are not the same written form. That distinction matters for decimal-place validation, scientific-notation constraints, exact-form rules, display, and telemetry.

### Why preserve `MultiplyStyle`?

Mathematically, these are equivalent:

```text
2x
2*x
```

But preserving whether multiplication was explicit or implicit is useful for:

- Debug output
- Rendering decisions
- Diagnostics
- Future exact-form rules
- Future feedback

Normalization can erase the distinction later. Parsing should preserve it while it is cheap to do so.

## Token design

The lexer should produce tokens with source spans.

Recommended token shape:

```gleam
pub type Token {
  NumberToken(literal: NumberLiteral, span: Span, leading_space: Bool)
  WordToken(raw: String, span: Span, leading_space: Bool)
  SymbolToken(symbol: Symbol, span: Span, leading_space: Bool)
}

pub type Symbol {
  Plus
  Minus
  Star
  Slash
  Caret
  LParen
  RParen
  Bar
  Bang
  Comma
}
```

Preserve `leading_space`.

This is useful for future unit parsing. For example:

```text
9.8 m/s^2
```

should eventually parse as a quantity, while:

```text
9.8m/s^2
```

may be rejected, treated as compact unit syntax, or interpreted differently depending on product decisions.

Keeping `leading_space` gives the parser enough information to distinguish a value-unit boundary from implicit multiplication.

## Lexer approach

The lexer should:

1. Convert the input string to UTF codepoints once.
2. Walk the codepoints recursively.
3. Track the current source offset.
4. Skip whitespace while remembering whether the next token had leading whitespace.
5. Build tokens in reverse order.
6. Reverse the final token list once.

Even though the input syntax is ASCII, use UTF codepoints so error reporting remains predictable for unsupported characters.

Character classification can be done with ordinal codepoint values:

```gleam
fn is_digit(cp: UtfCodepoint) -> Bool {
  let n = string.utf_codepoint_to_int(cp)
  n >= 48 && n <= 57
}

fn is_lower_alpha(cp: UtfCodepoint) -> Bool {
  let n = string.utf_codepoint_to_int(cp)
  n >= 97 && n <= 122
}

fn is_upper_alpha(cp: UtfCodepoint) -> Bool {
  let n = string.utf_codepoint_to_int(cp)
  n >= 65 && n <= 90
}
```

For this ASCII math parser, unsupported Unicode characters should produce clear errors rather than being accepted silently.

Examples:

```text
x²     -> unsupported character "²"; use ^ for exponents
1,000  -> unsupported character ","; thousands separators are not supported
```

## Number literal grammar

Start strict.

Recommended MVP grammar:

```text
digits := [0-9]+

number :=
  digits
  digits "." digits
  digits exponent
  digits "." digits exponent

exponent :=
  "e" ["+" | "-"] digits
  "E" ["+" | "-"] digits
```

Accepted:

```text
2
2.0
0.5
1.23e-4
6E7
```

Rejected for the POC:

```text
.5
1.
1,000
1e
1e+
```

This strict grammar can be relaxed later if product wants to accept `.5` or `1.`.

The parser should use the raw literal to compute:

```gleam
NumberLiteral(
  raw: "1.23e-4",
  value: 0.000123,
  notation: ScientificNotation,
  decimal_places: Some(2),
)
```

For scientific notation, `decimal_places` should refer to the mantissa's decimal places, not the final expanded value.

## Identifier handling

Identifier handling is one of the most important design decisions because the requirements include implicit multiplication like:

```text
xy
```

The parser should not blindly treat every alphabetic run as one variable.

Recommended MVP rules:

1. Recognize exact reserved constants:
   - `pi`
   - `e`

2. Recognize exact supported function names only when followed by `(`:
   - `sin(`
   - `cos(`
   - `tan(`
   - `ln(`
   - `log(`
   - `log10(`
   - `log2(`
   - `sqrt(`
   - `abs(`
   - `exp(`

3. If a supported function name appears without `(`, reject it:
   - `tan x` should produce a helpful error:
     - `Function "tan" requires parentheses: tan(x)`

4. For other alphabetic words, use single-letter-variable mode:
   - `x` -> `Var("x")`
   - `xy` -> `Var("x") * Var("y")`
   - `abc` -> `a * b * c`

5. Validation, not parsing, should reject variables that the item does not allow:
   - If only `x` and `y` are allowed, then `2z + 3` parses but fails validation.

This keeps the grammar simple and supports the MVP examples.

### Ambiguous examples

```text
sinx
```

For MVP, this can parse as:

```text
s * i * n * x
```

and later validation will probably reject `s`, `i`, and `n` as unexpected variables. If this produces confusing user feedback, add a special validation rule that detects reserved function prefixes without parentheses and suggests `sin(x)`.

```text
tan x
```

This should be rejected during parsing because `tan` is an exact supported function name without a required parenthesized argument.

```text
pi
```

This should parse as the constant `Pi`, not as `p * i`.

```text
e
```

This should parse as the constant `Euler`, unless product later decides to allow `e` as an author-configurable variable. For MVP, treating `e` as a reserved constant is cleaner.

## Parser algorithm

Use a Pratt parser.

A Pratt parser is a good fit because the grammar includes:

- Prefix operators: `-x`, `+x`
- Postfix operators: `n!`
- Infix operators: `+`, `-`, `*`, `/`, `^`
- Right-associative exponentiation: `2^3^4`
- Implicit multiplication: `2x`, `2(x+1)`, `xy`
- Function calls: `sqrt(2)`

A naive recursive-descent parser with one function per precedence level can work, but a Pratt parser tends to stay cleaner as the grammar grows.

## Operator precedence

Recommended precedence from lowest to highest:

| Precedence | Syntax | Meaning | Associativity |
|---:|---|---|---|
| 10 | `a + b`, `a - b` | add/subtract | left |
| 20 | `a * b`, `a / b` | explicit multiply/divide | left |
| 20 | `2x`, `2(x+1)`, `xy` | implicit multiply | left |
| 30 | `-x`, `+x` | unary sign | prefix |
| 40 | `a ^ b` | power | right |
| 50 | `x!` | factorial | postfix |
| 60 | `f(x)`, `(x)` | call/primary | primary |

The most important convention is:

```text
-x^2 -> -(x^2)
```

not:

```text
(-x)^2
```

This matches standard mathematical convention.

### Pratt binding-power detail

To parse `-x^2` as `-(x^2)` while still parsing `-x*y` as `(-x) * y`, the unary prefix parser should parse its operand with a binding power lower than exponentiation but higher than multiplication.

Conceptually:

```text
addition/subtraction: 10
multiplication/division/implicit multiplication: 20
unary prefix operand binding power: 30
power: 40
factorial: 50
```

So:

```text
-x^2
```

becomes:

```text
Negate(Power(x, 2))
```

and:

```text
-x*y
```

becomes:

```text
Multiply(Negate(x), y)
```

## Parsing flow

Internal parser state can be simple:

```gleam
type Parser {
  Parser(tokens: List(Token), config: ParseConfig)
}
```

Most internal functions should return both the parsed value and the updated parser state:

```gleam
fn parse_expr(
  parser: Parser,
  min_bp: Int,
) -> Result(#(Expr, Parser), ParseError)
```

Public parsing flow:

```text
parse(input):
  tokens = lexer.lex(input)
  parser = Parser(tokens, default_config)
  expr, parser = parse_expr(parser, 0)
  expect_end(parser)
  return Expression(expr)
```

Conceptual Pratt loop:

```text
parse_expr(min_bp):
  lhs = parse_prefix_or_primary()

  while next token is a postfix, infix, or implicit operator
        with binding power >= min_bp:
    consume operator
    parse rhs if needed
    lhs = combined expression

  return lhs
```

## Primary expressions

The parser should support these primary expressions:

```text
number
variable
constant
function_call
"(" expression ")"
"|" expression "|"
"+" expression
"-" expression
```

Examples:

```text
2
x
pi
sqrt(2)
(x+1)
|x-2|
-x
+x
```

## Postfix expressions

Postfix factorial:

```text
n!
(x+1)!
```

The parser should probably reject factorial on expressions that will not make mathematical sense later, but that can be validation/evaluation logic rather than parser logic.

For example, this can parse syntactically:

```text
(x+1)!
```

Then a later evaluator can decide whether factorial is valid only for non-negative integers.

## Function calls

Supported function calls:

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

For MVP, require parentheses.

Accepted:

```text
tan(x)
sqrt(2)
```

Rejected:

```text
tan x
sqrt 2
```

Use explicit errors:

```text
Function "tan" requires parentheses: tan(x)
```

Function arguments should be exactly one expression for MVP. Do not support multi-argument calls yet.

## Implicit multiplication

Implicit multiplication should be detected when the next token can start a primary expression.

Examples:

```text
2x         -> 2 * x
2(x+1)     -> 2 * (x+1)
xy         -> x * y
(x+1)(x-1) -> (x+1) * (x-1)
2sqrt(2)   -> 2 * sqrt(2)
```

This means the Pratt loop should treat “next token starts a primary” as an implicit multiplication operator.

A helper like this is useful:

```gleam
fn can_start_primary(token: Token) -> Bool
```

It should return `True` for:

- Number token
- Word token
- `(`
- `|`
- Prefix `+`
- Prefix `-`

Be careful with contexts where a token should end the current expression:

- `)`
- `|`
- end of input
- comma, if multi-argument functions are added later

## Ambiguity: `1/2x`

Pick one deterministic rule and document it.

Recommended MVP behavior:

```text
1/2x -> (1/2) * x
```

That follows the rule that explicit multiplication, division, and implicit multiplication all have the same precedence and are left-associative.

This is mathematically debatable because some people read `1/2x` as `1/(2x)`. To avoid ambiguity in authored content and student feedback, add a future lint or validation warning:

```text
Use parentheses to clarify ambiguous division with implicit multiplication.
```

For example:

```text
(1/2)x
1/(2x)
```

## Absolute value bars

Parse:

```text
|x-2|
```

as:

```text
Call(Abs, [x - 2])
```

or as a separate AST node if you want to preserve the exact syntax:

```gleam
AbsoluteValue(arg: Expr)
```

Recommendation for MVP:

- Parse `abs(x)` as `Call(Abs, [x])`
- Parse `|x|` as `Call(Abs, [x])`
- Optionally preserve source span and original syntax if needed for formatting

This keeps normalization and evaluation simpler.

Unclosed bars should produce:

```text
UnclosedAbsoluteValue(opened_at: Span)
```

## Error model

Use a custom error type with spans.

Do not return plain strings from the parser.

Recommended shape:

```gleam
pub type ParseError {
  UnexpectedToken(span: Span, expected: List(String), found: String)
  UnexpectedEnd(expected: List(String))
  InvalidNumber(span: Span, raw: String)
  UnsupportedCharacter(span: Span, raw: String)
  UnsupportedFunction(span: Span, name: String)
  FunctionRequiresParentheses(span: Span, name: String)
  UnclosedParenthesis(opened_at: Span)
  UnclosedAbsoluteValue(opened_at: Span)
  TrailingInput(span: Span)
}
```

These errors should later map cleanly to student-facing messages.

Examples:

```text
2^^3
```

Error:

```text
Unexpected token "^"; expected expression after "^".
```

```text
1,000
```

Error:

```text
Unsupported character ",". Thousands separators are not supported.
```

```text
tan x
```

Error:

```text
Function "tan" requires parentheses: tan(x).
```

```text
sqrt()
```

Error:

```text
Expected expression inside function call.
```

```text
|x-2
```

Error:

```text
Missing closing "|".
```

## Validation should be separate from parsing

Do not put all author-specific rules into the parser.

Parsing should accept syntactically valid math. Validation should check whether the parsed math is allowed for the current item.

For example:

```gleam
pub type SymbolConfig {
  SymbolConfig(
    allowed_variables: List(String),
    allowed_functions: List(FunctionName),
  )
}
```

Then:

```gleam
pub fn validate_symbols(
  parsed: Parsed,
  config: SymbolConfig,
) -> Result(Parsed, ValidationError)
```

Validation should handle:

- Unexpected variables
- Unsupported functions
- Units required but missing
- Units present but ignored
- Units not in accepted list
- Function whitelist checks
- Future exact-form constraints

This separation keeps the parser reusable across:

- Student client-side validation
- Author answer-key validation
- Server-side grading
- Preview tooling
- Telemetry

## Units as milestone 2

Units are important, but they complicate the grammar.

Treat unit parsing as milestone 2 after expression parsing is stable.

Recommended unit AST:

```gleam
pub type UnitExpr {
  UnitAtom(symbol: String)
  UnitMul(left: UnitExpr, right: UnitExpr)
  UnitDiv(left: UnitExpr, right: UnitExpr)
  UnitPow(unit: UnitExpr, exponent: Int)
}
```

Top-level parse result:

```gleam
pub type Parsed {
  Expression(Expr)
  Quantity(value: Expr, unit: UnitExpr)
}
```

Recommended unit grammar:

```text
unit_expr   := unit_factor (("*" | "/") unit_factor)*
unit_factor := unit_atom ["^" signed_integer]
unit_atom   := "m" | "s" | "cm" | "N" | ...
```

Accepted examples:

```text
9.8 m/s^2
980 cm/s^2
10 N
```

### Require a space before units in MVP

For MVP, require a space between the value and the unit:

```text
9.8 m/s^2  -> accepted
9.8m/s^2   -> rejected initially
```

This avoids ambiguity between variables and unit symbols.

The lexer’s `leading_space` metadata makes this possible.

### Quantity parsing strategy

When unit parsing is enabled:

1. Parse the numeric/expression value.
2. Stop expression parsing at a leading-space token that looks like a known unit atom.
3. Parse the rest of the input as a `UnitExpr`.

This prevents:

```text
9.8 m/s^2
```

from being parsed as:

```text
9.8 * m / s^2
```

The parser should not do unit conversion. It should only parse unit syntax. Unit normalization and conversion belong in a later unit evaluation layer.

## Formatting and debug output

Create a formatting module:

```text
gleam/src/math/format.gleam
```

For the POC, this module should produce stable debug output for golden tests.

Example:

```gleam
pub fn expr_to_debug_string(expr: Expr) -> String
pub fn parsed_to_debug_string(parsed: Parsed) -> String
```

Example output:

```text
Mul[implicit](
  Num(raw: "2", value: 2.0),
  Add(
    Var("x"),
    Num(raw: "3", value: 3.0)
  )
)
```

Keep this separate from JSON serialization. The POC needs stable testable output; production browser integration may later need JSON.

## JSON serialization

Do not make JSON encoding part of the core parser.

If the browser POC needs JSON, add a thin adapter module later:

```text
gleam/src/math/json.gleam
```

The parser should return Torus-owned Gleam types. JSON is just one representation of those types.

## Test strategy

The test suite is the most important part of the POC.

The first deliverable should be a golden test corpus that proves the parser behaves identically on BEAM and JavaScript.

Recommended commands:

```sh
cd gleam
gleam test --target erlang
gleam test --target javascript
```

If the default target is Erlang, this is also useful:

```sh
cd gleam
gleam test
gleam test --target javascript
```

## Lexer tests

Create:

```text
gleam/test/math_lexer_test.gleam
```

Test tokenization for:

```text
2
2.0
1.23e-4
x
xy
2x
2(x+3)
sqrt(2)
|x-2|
n!
```

Test invalid lexing for:

```text
1,000
x²
```

## Parser acceptance tests

Create:

```text
gleam/test/math_parser_test.gleam
```

Accepted inputs:

```text
2
2.0
1.23e-4
x
2x
xy
2(x+3)
(x+1)(x-1)
2x + 6
sqrt(2)/2
sin(x)
cos(x)
tan(x)
ln(x)
log(x)
log10(x)
log2(x)
abs(x)
exp(x)
pi
e
|x-2|
n!
2^3^4
-x^2
```

## Parser rejection tests

Rejected inputs:

```text
2^^3
1,000
tan x
sqrt()
(x+1
|x-2
2+
```

Each rejection test should assert the structured error type, not just that the parser failed.

## Precedence tests

Create:

```text
gleam/test/math_precedence_test.gleam
```

Important precedence expectations:

```text
2+3*4      -> 2 + (3*4)
2*3+4      -> (2*3) + 4
2^3^4      -> 2^(3^4)
-x^2       -> -(x^2)
(-x)^2     -> (-x)^2
2x^2       -> 2*(x^2)
1/2x       -> (1/2)*x
```

## Unit milestone tests

Create later:

```text
gleam/test/math_units_test.gleam
```

Accepted:

```text
9.8 m/s^2
980 cm/s^2
10 N
```

Rejected or validation-failed, depending on configuration:

```text
9.8 mph
9.8m/s^2
```

## Implementation sequence

Build in this order.

### 1. Define AST and error types

Create:

```text
gleam/src/math/ast.gleam
```

Include:

- `Parsed`
- `Expr`
- `ExprKind`
- `NumberLiteral`
- `NumberNotation`
- `Constant`
- `PrefixOp`
- `BinaryOp`
- `MultiplyStyle`
- `FunctionName`
- `Span`
- `ParseError`

### 2. Define tokens

Create:

```text
gleam/src/math/token.gleam
```

Include:

- `Token`
- `Symbol`
- token helper functions
- span helper functions

### 3. Build the lexer

Create:

```text
gleam/src/math/lexer.gleam
```

Support:

- Whitespace skipping
- `leading_space`
- Number scanning
- Word scanning
- Symbol scanning
- Unsupported character errors

### 4. Build the basic Pratt parser

Create:

```text
gleam/src/math/parser.gleam
```

Initially support:

- Numbers
- Variables
- Constants
- `+`
- `-`
- `*`
- `/`
- `^`
- Parentheses

### 5. Add implicit multiplication

Support:

```text
2x
2(x+1)
xy
(x+1)(x-1)
2sqrt(2)
```

### 6. Add functions and constants

Support:

```text
sqrt(2)
sin(x)
cos(x)
tan(x)
ln(x)
log(x)
log10(x)
log2(x)
abs(x)
exp(x)
pi
e
```

Reject:

```text
tan x
sqrt 2
```

### 7. Add absolute value and factorial

Support:

```text
|x-2|
n!
```

### 8. Add validation pass

Create:

```text
gleam/src/math/validate.gleam
```

Start with:

- Allowed variables
- Allowed functions

### 9. Add formatting for demos

Create:

```text
gleam/src/math/format.gleam
```

Support stable AST debug output.

### 10. Run both targets

Run:

```sh
cd gleam
gleam test --target erlang
gleam test --target javascript
```

### 11. Add units as milestone 2

Create or expand:

```text
gleam/src/math/unit.gleam
```

Add:

- `UnitExpr`
- Unit parser
- Unit validation
- Quantity parsing

## Example parser internals

The key internal parser function will likely look like this conceptually:

```gleam
fn parse_expr(
  parser: Parser,
  min_bp: Int,
) -> Result(#(Expr, Parser), ParseError) {
  use #(lhs, parser) <- result.try(parse_prefix_or_primary(parser))
  parse_loop(lhs, parser, min_bp)
}
```

The loop decides whether to consume:

- Postfix factorial
- Explicit infix operator
- Implicit multiplication
- Nothing

Conceptually:

```gleam
fn parse_loop(lhs: Expr, parser: Parser, min_bp: Int) {
  case peek(parser) {
    Ok(Bang) if postfix_bp >= min_bp ->
      consume and produce Factorial(lhs)

    Ok(operator) if infix operator binding power >= min_bp ->
      consume operator
      parse rhs
      produce Binary(operator, lhs, rhs)

    Ok(token) if can_start_primary(token) && implicit_mul_bp >= min_bp ->
      parse rhs
      produce Binary(Multiply(ImplicitMultiply), lhs, rhs)

    _ ->
      return lhs
  }
}
```

Right-associative power needs special handling. Conceptually:

```text
left binding power: 40
right binding power: 39
```

or any equivalent Pratt convention that ensures:

```text
2^3^4 -> 2^(3^4)
```

## Expected POC demo

A simple CLI or test output should show:

```text
Input: 2(x+3)
OK:
Mul[implicit](
  Num("2"),
  Add(Var("x"), Num("3"))
)

Input: sqrt(2)/2
OK:
Div(
  Call(Sqrt, Num("2")),
  Num("2")
)

Input: 2x + 6
OK:
Add(
  Mul[implicit](Num("2"), Var("x")),
  Num("6")
)

Input: 1.2e-3
OK:
Num(raw: "1.2e-3", value: 0.0012, notation: ScientificNotation)

Input: 2^^3
ERROR:
Unexpected token "^"; expected expression after "^".
```

## Key design decisions to document

### Decision 1: Parser is pure Gleam

No Erlang-only or JavaScript-only externals in the parser.

Reason:

- The same parser should run client-side and server-side.
- The same golden tests should pass on both targets.
- Parser behavior should not drift by runtime.

### Decision 2: Parser and evaluator are separate

Reason:

- Parsing is syntax.
- Evaluation is math semantics.
- Validation is author-configuration semantics.

Keeping these separate makes the implementation easier to test and safer to evolve.

### Decision 3: Use a Pratt parser

Reason:

- Handles precedence cleanly.
- Handles prefix, postfix, infix, and implicit operators.
- Keeps the grammar extensible.

### Decision 4: Preserve source spans

Reason:

- Needed for good error messages.
- Needed for client-side highlighting.
- Useful for telemetry and debugging.

### Decision 5: Preserve raw number literals

Reason:

- Needed for decimal precision.
- Needed for numeric representation rules.
- Needed for exact-form feedback.
- Float value alone loses important form information.

### Decision 6: Units are parsed separately after expression parsing is stable

Reason:

- Units introduce ambiguity with variables and implicit multiplication.
- A stable pure expression parser is easier to prove first.
- Unit conversion belongs in a later evaluator layer, not in the parser.

## Main risks

### Risk: Identifier ambiguity

Examples:

```text
xy
pi
sinx
tan x
```

Mitigation:

- Reserve exact constants.
- Require function parentheses.
- Use single-letter-variable mode for other alphabetic runs.
- Add validation warnings for likely function-parentheses mistakes.

### Risk: Implicit multiplication ambiguity

Example:

```text
1/2x
```

Mitigation:

- Define deterministic MVP behavior: `(1/2) * x`.
- Add future lint warning for ambiguous division with implicit multiplication.

### Risk: Unit ambiguity

Examples:

```text
9.8 m/s^2
9.8m/s^2
```

Mitigation:

- Require a space before units in MVP.
- Preserve `leading_space` in tokens.
- Use known unit symbols when deciding value/unit boundary.

### Risk: Runtime float differences

Gleam runs on both BEAM and JavaScript, and the runtimes may differ in some floating-point edge behavior.

Mitigation for parser POC:

- Use floats only for literal numeric value parsing.
- Preserve raw literals.
- Avoid evaluator semantics in parser POC.
- Add cross-target tests for accepted numeric literal parsing.

### Risk: Error messages become hard to maintain

Mitigation:

- Parser returns structured `ParseError`.
- UI formatting of errors happens separately.
- Tests assert error variants and spans.

## Success criteria

The POC is successful when:

1. `gleam/src/math.gleam` exposes a clean `parse` function.
2. The parser accepts the core ASCII math examples.
3. The parser rejects invalid examples with structured errors.
4. The parser produces stable Torus-owned AST values.
5. Golden tests pass under BEAM.
6. The same golden tests pass under JavaScript.
7. The design leaves room for validation, normalization, evaluation, and unit handling without rewriting the parser.

## Recommended immediate next step

Start by implementing:

```text
gleam/src/math/ast.gleam
gleam/src/math/token.gleam
gleam/src/math/lexer.gleam
gleam/src/math/parser.gleam
gleam/src/math.gleam
gleam/test/math_parser_test.gleam
```

Then create a very small demo corpus:

```text
2
x
2x
2(x+3)
2x + 6
sqrt(2)/2
1.2e-3
2^^3
```

Once those pass on both targets, add the rest of the syntax incrementally.

The proof of concept should stay focused on the strongest architecture claim:

> We can author the math syntax layer once in Gleam, run it in the browser and on the server, and get the same AST from the same student input.
