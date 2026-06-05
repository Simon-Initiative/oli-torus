import gleeunit
import math/ast
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn symbol_config_contract_test() {
  let config =
    ast.SymbolConfig(allowed_variables: ["x", "y"], allowed_functions: [
      ast.Sin,
      ast.Sqrt,
    ])

  assert config
    == ast.SymbolConfig(allowed_variables: ["x", "y"], allowed_functions: [
      ast.Sin,
      ast.Sqrt,
    ])
}

pub fn validation_accepts_configured_symbols_test() {
  let assert Ok(parsed) = torus_math.parse("sqrt(x)+sin(y)")

  let config =
    ast.SymbolConfig(allowed_variables: ["x", "y"], allowed_functions: [
      ast.Sqrt,
      ast.Sin,
    ])

  assert torus_math.validate_symbols(parsed, config) == Ok(parsed)
}

pub fn validation_rejects_unconfigured_variables_without_changing_parse_test() {
  let assert Ok(parsed) = torus_math.parse("2z + 3")

  let config =
    ast.SymbolConfig(allowed_variables: ["x"], allowed_functions: [
      ast.Sqrt,
    ])

  assert torus_math.validate_symbols(parsed, config)
    == Error(ast.UnexpectedVariable(span: ast.Span(start: 1, end: 2), name: "z"))
}

pub fn validation_rejects_disallowed_functions_test() {
  let assert Ok(parsed) = torus_math.parse("sqrt(x)")

  let config =
    ast.SymbolConfig(allowed_variables: ["x"], allowed_functions: [
      ast.Sin,
    ])

  assert torus_math.validate_symbols(parsed, config)
    == Error(ast.DisallowedFunction(
      span: ast.Span(start: 0, end: 7),
      name: ast.Sqrt,
    ))
}
