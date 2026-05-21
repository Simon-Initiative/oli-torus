import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
import math/ast
import math/equality/algebraic_types
import math/format as ast_format
import math/normalization/format as normal_format
import math/normalization/normalize
import math/normalization/types as normal_types
import math/parser
import math/sampling/domain
import math/sampling/sample
import math/sampling/tolerance
import math/sampling/types as sampling_types

/// A prepared expression contains the normalized expression plus stable
/// developer diagnostics and symbol metadata used by validation.
pub type PreparedExpression {
  PreparedExpression(
    expression: normal_types.NormalExpr,
    debug: algebraic_types.ExpressionDebug,
    variables: List(String),
    functions: List(ast.FunctionName),
  )
}

/// Validated algebraic inputs are the handoff point from preparation to the
/// later equivalence algorithm. This type deliberately contains no pass/fail
/// comparison result.
pub type PreparedAlgebraicInputs {
  PreparedAlgebraicInputs(
    expected: PreparedExpression,
    candidate: PreparedExpression,
    allowed_variables: List(String),
    variables_to_sample: List(String),
    domains: sampling_types.DomainConfig,
    config: algebraic_types.AlgebraicEquivalenceConfig,
  )
}

/// Pipeline errors are preparation failures, not mathematical
/// non-equivalence. Keeping them distinct lets callers map parse,
/// validation, and config failures to precise result outcomes.
pub type PipelineError {
  ExpectedParseFailure(error: ast.ParseError)
  CandidateParseFailure(error: ast.ParseError)
  UnsupportedShape(side: algebraic_types.ExpressionSide, reason: String)
  ValidationFailure(errors: List(algebraic_types.AlgebraicValidationError))
  ConfigurationFailure(error: algebraic_types.AlgebraicConfigError)
}

/// Parse, structurally normalize, validate, and summarize two raw expression
/// strings without deciding algebraic equivalence.
pub fn prepare_raw(
  expected_source: String,
  candidate_source: String,
  config: algebraic_types.AlgebraicEquivalenceConfig,
) -> Result(PreparedAlgebraicInputs, PipelineError) {
  use expected_parsed <- result.try(
    parser.parse(expected_source)
    |> result.map_error(ExpectedParseFailure),
  )
  use candidate_parsed <- result.try(
    parser.parse(candidate_source)
    |> result.map_error(CandidateParseFailure),
  )

  use expected <- result.try(prepare_parsed(
    expected_parsed,
    algebraic_types.ExpectedExpression,
  ))
  use candidate <- result.try(prepare_parsed(
    candidate_parsed,
    algebraic_types.CandidateExpression,
  ))

  validate_prepared(expected, candidate, config)
}

/// Validate two already-normalized expression trees. This supports the lower
/// level API while preserving the same variable/function policy as raw-string
/// preparation.
pub fn prepare_normalized(
  expected_expression: normal_types.NormalExpr,
  candidate_expression: normal_types.NormalExpr,
  config: algebraic_types.AlgebraicEquivalenceConfig,
) -> Result(PreparedAlgebraicInputs, PipelineError) {
  let expected = prepare_normal_expr(expected_expression)
  let candidate = prepare_normal_expr(candidate_expression)

  validate_prepared(expected, candidate, config)
}

/// Collect variables from a normalized expression in stable sorted order.
pub fn variables_in_expression(
  expression: normal_types.NormalExpr,
) -> List(String) {
  expression
  |> collect_variables([])
  |> stable_unique_strings
}

/// Collect function names from a normalized expression in stable sorted order.
pub fn functions_in_expression(
  expression: normal_types.NormalExpr,
) -> List(ast.FunctionName) {
  expression
  |> collect_functions([])
  |> stable_unique_functions
}

/// Prepare one parser result into a normalized expression and debug metadata.
/// Quantity/unit shapes deliberately stop here because algebraic equivalence
/// does not yet define unit-aware comparison semantics.
pub fn prepare_parsed(
  parsed: ast.Parsed,
  side: algebraic_types.ExpressionSide,
) -> Result(PreparedExpression, PipelineError) {
  let normalized = normalize.structural_normalize(parsed)

  case normalized.normal {
    normal_types.NormalExpression(expression) ->
      Ok(prepared_expression(
        expression,
        parsed_debug: ast_format.to_debug_string(parsed),
        normalized_debug: normal_format.normalized_to_debug_string(normalized),
      ))

    normal_types.NormalQuantity(_, _) ->
      Error(UnsupportedShape(
        side: side,
        reason: "unit-bearing normalized quantities are not supported",
      ))
  }
}

fn prepare_normal_expr(
  expression: normal_types.NormalExpr,
) -> PreparedExpression {
  let normalized =
    normal_types.Normalized(
      original: ast.Expression(placeholder_expr()),
      normal: normal_types.NormalExpression(expression),
      warnings: [],
    )

  prepared_expression(
    expression,
    parsed_debug: "NormalizedExpressionInput",
    normalized_debug: normal_format.normalized_to_debug_string(normalized),
  )
}

fn prepared_expression(
  expression: normal_types.NormalExpr,
  parsed_debug parsed_debug: String,
  normalized_debug normalized_debug: String,
) -> PreparedExpression {
  let variables = variables_in_expression(expression)

  PreparedExpression(
    expression: expression,
    debug: algebraic_types.ExpressionDebug(
      parsed_debug: parsed_debug,
      normalized_debug: normalized_debug,
      variables: variables,
    ),
    variables: variables,
    functions: functions_in_expression(expression),
  )
}

fn validate_prepared(
  expected: PreparedExpression,
  candidate: PreparedExpression,
  config: algebraic_types.AlgebraicEquivalenceConfig,
) -> Result(PreparedAlgebraicInputs, PipelineError) {
  use domains <- result.try(
    domain.validate_domain_config(config.domains)
    |> result.map_error(fn(error) {
      ConfigurationFailure(algebraic_types.InvalidDomainConfig(error))
    }),
  )
  use Nil <- result.try(
    sample.validate_sampling_config(config.sampling)
    |> result.map_error(fn(error) {
      ConfigurationFailure(algebraic_types.InvalidSamplingConfig(error))
    }),
  )
  use Nil <- result.try(
    tolerance.compare_numbers(0.0, 0.0, config.tolerance)
    |> result.map(fn(_) { Nil })
    |> result.map_error(fn(error) {
      ConfigurationFailure(algebraic_types.InvalidToleranceConfig(error))
    }),
  )
  use allowed_variables <- result.try(resolve_allowed_variables(
    config.allowed_variables,
    expected.variables,
  ))

  let allowed_functions = resolve_allowed_functions(config.allowed_functions)
  let validation_errors =
    list.append(
      list.append(
        validate_variables(
          expected.variables,
          allowed_variables,
          algebraic_types.ExpectedExpression,
        ),
        validate_variables(
          candidate.variables,
          allowed_variables,
          algebraic_types.CandidateExpression,
        ),
      ),
      list.append(
        validate_functions(
          expected.functions,
          allowed_functions,
          algebraic_types.ExpectedExpression,
        ),
        validate_functions(
          candidate.functions,
          allowed_functions,
          algebraic_types.CandidateExpression,
        ),
      ),
    )

  case validation_errors {
    [] ->
      Ok(PreparedAlgebraicInputs(
        expected: expected,
        candidate: candidate,
        allowed_variables: allowed_variables,
        // Sampling only variables that actually appear in validated
        // expressions is a product policy: explicit allow-lists can authorize
        // a candidate-only canceling variable without adding unused author
        // variables to every assignment.
        variables_to_sample: list.append(
          expected.variables,
          candidate.variables,
        )
          |> stable_unique_strings,
        domains: domains,
        config: config,
      ))

    _ -> Error(ValidationFailure(validation_errors))
  }
}

fn resolve_allowed_variables(
  policy: algebraic_types.AllowedVariables,
  expected_variables: List(String),
) -> Result(List(String), PipelineError) {
  case policy {
    algebraic_types.InferFromExpected ->
      // The default inferred allow-list is intentionally based only on the
      // expected expression. Candidate-only variables therefore fail validation
      // unless the caller opts into an explicit allow-list.
      Ok(expected_variables)

    algebraic_types.ExplicitAllowedVariables(names) -> {
      let sorted = list.sort(names, by: string.compare)
      let duplicate_errors =
        duplicates(sorted, [])
        |> list.map(fn(name) {
          algebraic_types.DuplicateAllowedVariable(name: name)
        })
      let invalid_errors =
        sorted
        |> list.filter_map(fn(name) {
          case is_variable_name(name) {
            True -> Error(Nil)
            False ->
              Ok(algebraic_types.InvalidAllowedVariable(
                name: name,
                reason: "must be one variable symbol",
              ))
          }
        })

      case list.append(duplicate_errors, invalid_errors) {
        [] -> Ok(stable_unique_strings(sorted))
        errors -> Error(ValidationFailure(errors))
      }
    }
  }
}

fn resolve_allowed_functions(
  policy: algebraic_types.AllowedFunctions,
) -> List(ast.FunctionName) {
  case policy {
    algebraic_types.DefaultSupportedFunctions -> default_supported_functions()
    algebraic_types.ExplicitAllowedFunctions(names) ->
      stable_unique_functions(names)
  }
}

fn validate_variables(
  variables: List(String),
  allowed_variables: List(String),
  side: algebraic_types.ExpressionSide,
) -> List(algebraic_types.AlgebraicValidationError) {
  variables
  |> list.filter_map(fn(name) {
    case list.contains(allowed_variables, any: name) {
      True -> Error(Nil)
      False -> Ok(algebraic_types.UnexpectedVariable(side: side, name: name))
    }
  })
}

fn validate_functions(
  functions: List(ast.FunctionName),
  allowed_functions: List(ast.FunctionName),
  side: algebraic_types.ExpressionSide,
) -> List(algebraic_types.AlgebraicValidationError) {
  functions
  |> list.filter_map(fn(name) {
    case list.contains(allowed_functions, any: name) {
      True -> Error(Nil)
      False -> Ok(algebraic_types.DisallowedFunction(side: side, name: name))
    }
  })
}

fn collect_variables(
  expression: normal_types.NormalExpr,
  variables: List(String),
) -> List(String) {
  case expression {
    normal_types.NVariable(name, _) -> [name, ..variables]
    normal_types.NNumber(_, _, _) | normal_types.NConstant(_, _) -> variables
    normal_types.NSum(terms, _) | normal_types.NProduct(terms, _) ->
      collect_variables_from_list(terms, variables)
    normal_types.NPower(base, exponent, _) ->
      collect_variables(exponent, collect_variables(base, variables))
    normal_types.NCall(_, args, _) ->
      collect_variables_from_list(args, variables)
    normal_types.NAbs(arg, _)
    | normal_types.NFactorial(arg, _)
    | normal_types.NNegate(arg, _) -> collect_variables(arg, variables)
    normal_types.NDivide(left, right, _) ->
      collect_variables(right, collect_variables(left, variables))
  }
}

fn collect_variables_from_list(
  expressions: List(normal_types.NormalExpr),
  variables: List(String),
) -> List(String) {
  case expressions {
    [] -> variables
    [expression, ..rest] ->
      collect_variables_from_list(
        rest,
        collect_variables(expression, variables),
      )
  }
}

fn collect_functions(
  expression: normal_types.NormalExpr,
  functions: List(ast.FunctionName),
) -> List(ast.FunctionName) {
  case expression {
    normal_types.NNumber(_, _, _)
    | normal_types.NVariable(_, _)
    | normal_types.NConstant(_, _) -> functions
    normal_types.NSum(terms, _) | normal_types.NProduct(terms, _) ->
      collect_functions_from_list(terms, functions)
    normal_types.NPower(base, exponent, _) ->
      collect_functions(exponent, collect_functions(base, functions))
    normal_types.NCall(name, args, _) ->
      collect_functions_from_list(args, [name, ..functions])
    normal_types.NAbs(arg, _) -> collect_functions(arg, [ast.Abs, ..functions])
    normal_types.NFactorial(arg, _) | normal_types.NNegate(arg, _) ->
      collect_functions(arg, functions)
    normal_types.NDivide(left, right, _) ->
      collect_functions(right, collect_functions(left, functions))
  }
}

fn collect_functions_from_list(
  expressions: List(normal_types.NormalExpr),
  functions: List(ast.FunctionName),
) -> List(ast.FunctionName) {
  case expressions {
    [] -> functions
    [expression, ..rest] ->
      collect_functions_from_list(
        rest,
        collect_functions(expression, functions),
      )
  }
}

fn stable_unique_strings(values: List(String)) -> List(String) {
  values
  |> list.sort(by: string.compare)
  |> unique_sorted_strings([])
}

fn unique_sorted_strings(
  values: List(String),
  kept: List(String),
) -> List(String) {
  case values {
    [] -> list.reverse(kept)
    [value, ..rest] ->
      case kept {
        [previous, ..] if previous == value -> unique_sorted_strings(rest, kept)
        _ -> unique_sorted_strings(rest, [value, ..kept])
      }
  }
}

fn duplicates(values: List(String), found: List(String)) -> List(String) {
  case values {
    [] | [_] -> list.reverse(found)
    [first, second, ..rest] ->
      case first == second && !list.contains(found, any: first) {
        True -> duplicates([second, ..rest], [first, ..found])
        False -> duplicates([second, ..rest], found)
      }
  }
}

fn stable_unique_functions(
  values: List(ast.FunctionName),
) -> List(ast.FunctionName) {
  values
  |> list.sort(by: compare_functions)
  |> unique_sorted_functions([])
}

fn unique_sorted_functions(
  values: List(ast.FunctionName),
  kept: List(ast.FunctionName),
) -> List(ast.FunctionName) {
  case values {
    [] -> list.reverse(kept)
    [value, ..rest] ->
      case kept {
        [previous, ..] if previous == value ->
          unique_sorted_functions(rest, kept)
        _ -> unique_sorted_functions(rest, [value, ..kept])
      }
  }
}

fn compare_functions(
  left: ast.FunctionName,
  right: ast.FunctionName,
) -> order.Order {
  int_compare(function_rank(left), function_rank(right))
}

fn int_compare(left: Int, right: Int) -> order.Order {
  case left < right {
    True -> order.Lt
    False ->
      case left > right {
        True -> order.Gt
        False -> order.Eq
      }
  }
}

fn function_rank(name: ast.FunctionName) -> Int {
  case name {
    ast.Sin -> 0
    ast.Cos -> 1
    ast.Tan -> 2
    ast.Ln -> 3
    ast.Log -> 4
    ast.Log10 -> 5
    ast.Log2 -> 6
    ast.Sqrt -> 7
    ast.Abs -> 8
    ast.Exp -> 9
  }
}

fn default_supported_functions() -> List(ast.FunctionName) {
  [
    ast.Sin,
    ast.Cos,
    ast.Tan,
    ast.Ln,
    ast.Log,
    ast.Log10,
    ast.Log2,
    ast.Sqrt,
    ast.Abs,
    ast.Exp,
  ]
}

fn is_variable_name(name: String) -> Bool {
  case parser.parse(name) {
    Ok(ast.Expression(ast.Expr(kind: ast.Var(variable), ..))) ->
      variable == name
    _ -> False
  }
}

fn placeholder_expr() -> ast.Expr {
  ast.Expr(
    kind: ast.Num(ast.NumberLiteral(
      raw: "0",
      value: 0.0,
      notation: ast.IntegerNotation,
      decimal_places: option.None,
    )),
    span: ast.Span(start: 0, end: 1),
  )
}
