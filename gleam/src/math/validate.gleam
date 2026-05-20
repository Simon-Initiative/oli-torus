import gleam/list
import math/ast

/// Validation intentionally accepts an already parsed AST. This keeps syntactic
/// parser success independent from author settings, so activities can decide
/// whether a symbol is allowed without changing what the parser recognizes.
pub fn validate_symbols(
  parsed: ast.Parsed,
  config: ast.SymbolConfig,
) -> Result(ast.Parsed, ast.ValidationError) {
  case parsed {
    ast.Expression(expr) ->
      case validate_expr(expr, config) {
        Ok(Nil) -> Ok(parsed)
        Error(error) -> Error(error)
      }

    ast.Quantity(value, _unit) ->
      // Unit parsing is deferred, but a future quantity should still validate
      // the expression value here before unit-specific validation runs elsewhere.
      case validate_expr(value, config) {
        Ok(Nil) -> Ok(parsed)
        Error(error) -> Error(error)
      }
  }
}

fn validate_expr(
  expr: ast.Expr,
  config: ast.SymbolConfig,
) -> Result(Nil, ast.ValidationError) {
  case expr.kind {
    ast.Num(_) -> Ok(Nil)
    ast.Const(_) -> Ok(Nil)

    ast.Var(name) -> {
      case list.contains(config.allowed_variables, any: name) {
        True -> Ok(Nil)
        False -> Error(ast.UnexpectedVariable(span: expr.span, name: name))
      }
    }

    ast.Prefix(arg: arg, ..) -> validate_expr(arg, config)

    ast.Binary(left: left, right: right, ..) ->
      case validate_expr(left, config) {
        Ok(Nil) -> validate_expr(right, config)
        Error(error) -> Error(error)
      }

    ast.Call(name: name, args: args) -> {
      case list.contains(config.allowed_functions, any: name) {
        True -> validate_args(args, config)
        False -> Error(ast.DisallowedFunction(span: expr.span, name: name))
      }
    }

    ast.Factorial(arg: arg) -> validate_expr(arg, config)
  }
}

fn validate_args(
  args: List(ast.Expr),
  config: ast.SymbolConfig,
) -> Result(Nil, ast.ValidationError) {
  case args {
    [] -> Ok(Nil)
    [first, ..rest] ->
      case validate_expr(first, config) {
        Ok(Nil) -> validate_args(rest, config)
        Error(error) -> Error(error)
      }
  }
}
