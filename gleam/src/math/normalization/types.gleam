import math/ast

/// A normalized result keeps the original parser output beside the normalized
/// structure so exact-form checks, source highlighting, and future diagnostics
/// never need to reconstruct source details from canonicalized data.
pub type Normalized {
  Normalized(
    original: ast.Parsed,
    normal: NormalParsed,
    warnings: List(NormalizationWarning),
  )
}

/// The parsed input can be either an expression or a reserved quantity shape.
/// Quantity support is intentionally structural only for now: the value can be
/// normalized as an expression, while unit semantics remain a future layer.
pub type NormalParsed {
  NormalExpression(NormalExpr)
  NormalQuantity(value: NormalExpr, unit: NormalUnitExpr)
}

/// The normalized expression tree is separate from `ast.Expr` so the parser can
/// preserve written form while normalization owns stable semantic shape. Divide
/// and negate remain explicit variants because rewriting them away can change
/// domains or hide undefined subexpressions.
pub type NormalExpr {
  NNumber(value: ExactNumber, source: ast.NumberLiteral, span: ast.Span)
  NVariable(name: String, span: ast.Span)
  NConstant(constant: ast.Constant, span: ast.Span)
  NSum(terms: List(NormalExpr), span: ast.Span)
  NProduct(factors: List(NormalExpr), span: ast.Span)
  NPower(base: NormalExpr, exponent: NormalExpr, span: ast.Span)
  NCall(name: ast.FunctionName, args: List(NormalExpr), span: ast.Span)
  NAbs(arg: NormalExpr, span: ast.Span)
  NFactorial(arg: NormalExpr, span: ast.Span)
  NNegate(arg: NormalExpr, span: ast.Span)
  NDivide(left: NormalExpr, right: NormalExpr, span: ast.Span)
}

/// Unit-specific normalized nodes are included now so callers can depend on one
/// result shape later, but Phase 1 does not perform unit algebra, conversion, or
/// dimensional equivalence. Unsupported unit structures keep their original AST.
pub type NormalUnitExpr {
  NUnitAtom(symbol: String, span: ast.Span)
  NUnitProduct(factors: List(NormalUnitExpr), span: ast.Span)
  NUnitQuotient(
    numerator: NormalUnitExpr,
    denominator: NormalUnitExpr,
    span: ast.Span,
  )
  NUnitPower(unit: NormalUnitExpr, exponent: Int, span: ast.Span)
  NUnitUnsupported(original: ast.UnitExpr)
}

/// Exact numbers start conservative so BEAM and JavaScript targets cannot drift
/// by overflowing or formatting large values differently. Raw literals stay
/// available for exact-form rules even when a value can be normalized.
pub type ExactNumber {
  ExactInteger(value: Int)
  ExactRational(numerator: Int, denominator: Int)
  ExactDecimal(raw: String, numerator: Int, denominator: Int)
  ApproximateFloat(raw: String, value: Float)
  LargeNumber(raw: String)
}

/// Normalization warnings are developer/prototype diagnostics. They describe
/// intentional limits in the normalizer and must not be treated as student-
/// facing feedback without a later product and privacy review.
pub type NormalizationWarning {
  LargeExactNumberKeptAsString(span: ast.Span)
  DomainSensitiveRewriteSkipped(span: ast.Span)
  UnitSemanticNormalizationUnsupported
}
