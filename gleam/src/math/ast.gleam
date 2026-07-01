import gleam/option.{type Option}

/// The top-level parse result is intentionally broader than the Phase 1 parser.
/// `Quantity` is reserved now so later unit parsing can attach units without
/// replacing the public type that Torus callers depend on.
pub type Parsed {
  Expression(Expr)
  Quantity(value: Expr, unit: UnitExpr)
}

/// Every expression carries a span because UI highlighting, diagnostics, and
/// future telemetry need source locations even when the AST is transformed.
pub type Expr {
  Expr(kind: ExprKind, span: Span)
}

/// The parser owns syntax only. Evaluation-specific meaning, such as whether a
/// factorial argument is mathematically valid, belongs in later layers.
pub type ExprKind {
  Num(NumberLiteral)
  Var(String)
  Const(Constant)
  Prefix(op: PrefixOp, arg: Expr)
  Binary(op: BinaryOp, left: Expr, right: Expr)
  Call(name: FunctionName, args: List(Expr))
  Factorial(arg: Expr)
}

/// Numeric literals preserve both parsed value and written form. Future decimal
/// place rules, scientific-notation constraints, and exact-form feedback need
/// the original raw string; a Float alone would lose that information.
pub type NumberLiteral {
  NumberLiteral(
    raw: String,
    value: Float,
    notation: NumberNotation,
    decimal_places: Option(Int),
  )
}

/// The notation is separate from the raw literal so validators can reason about
/// author constraints without reparsing strings.
pub type NumberNotation {
  IntegerNotation
  DecimalNotation
  ScientificNotation
}

/// Constants are reserved at parse time to keep `pi` and `e` stable across
/// browser and server parsing.
pub type Constant {
  Pi
  Euler
}

/// Prefix operators are modeled separately from binary operators so precedence
/// choices such as `-x^2` can be represented explicitly by the parser.
pub type PrefixOp {
  Negate
  Positive
}

/// Multiplication carries a style so diagnostics and exact-form rules can later
/// distinguish `2x` from `2*x` before normalization erases that distinction.
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

/// The MVP function set mirrors the proposed ASCII math syntax exactly. Adding
/// functions later should be a deliberate contract change with corpus coverage.
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

/// Unit syntax is deferred, but the AST reserves a shape so the future quantity
/// milestone does not need to redefine `Parsed`.
pub type UnitExpr {
  UnitAtom(symbol: String)
  UnitMul(left: UnitExpr, right: UnitExpr)
  UnitDiv(left: UnitExpr, right: UnitExpr)
  UnitPow(unit: UnitExpr, exponent: Int)
}

/// Spans use source offsets so both BEAM and JavaScript callers can map errors
/// back onto the same input string.
pub type Span {
  Span(start: Int, end: Int)
}

/// `ParseConfig` is intentionally small in Phase 1. It exists so future
/// grammar-level toggles can be added without using author-specific validation
/// settings inside the syntactic parser.
pub type ParseConfig {
  ParseConfig
}

/// Parser failures are structured from the start. UI copy can be built later,
/// but the parser should never collapse failures into plain strings.
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

/// Validation is separated from parsing so syntactically valid math can be
/// checked against each activity's author configuration later.
pub type SymbolConfig {
  SymbolConfig(
    allowed_variables: List(String),
    allowed_functions: List(FunctionName),
  )
}

/// Validation errors keep spans because authoring and learner UIs need to point
/// at the offending symbol without changing parser behavior.
pub type ValidationError {
  UnexpectedVariable(span: Span, name: String)
  DisallowedFunction(span: Span, name: FunctionName)
}

/// The default parse config is centralized so callers do not invent their own
/// defaults before grammar toggles exist.
pub fn default_parse_config() -> ParseConfig {
  ParseConfig
}
