import math/ast
import math/equality/algebraic
import math/equality/algebraic_format
import math/equality/algebraic_types
import math/equality/evaluate
import math/equality/form as exact_form
import math/equality/form_format
import math/equality/form_types
import math/equality/json
import math/equality/types
import math/format
import math/latex
import math/match/evaluate as match_evaluate
import math/match/json as match_json
import math/match/types as match_types
import math/normalization/format as normalization_format
import math/normalization/hash as normalization_hash
import math/normalization/normalize as normalization
import math/normalization/types as normalization_types
import math/parser
import math/sampling/evaluate as sampling_evaluate
import math/sampling/format as sampling_format
import math/sampling/sample as sampling_sample
import math/sampling/tolerance as sampling_tolerance
import math/sampling/types as sampling_types
import math/units/catalog as units_catalog
import math/units/compare as units_compare
import math/units/config as units_config
import math/units/format as units_format
import math/units/normalize as units_normalize
import math/units/parser as units_parser
import math/units/quantity as units_quantity
import math/units/types as units_types
import math/validate

/// This module is named `torus_math` instead of `math` because `math` collides
/// with Erlang's standard `math` module on the BEAM target. It remains the only
/// parser API Torus callers should depend on, so internal lexer/parser modules
/// can evolve without creating server/browser drift.
pub fn parse(input: String) -> Result(ast.Parsed, ast.ParseError) {
  parser.parse(input)
}

/// This overload point is reserved for grammar-level parser options. It accepts
/// a config now so later phases can add behavior without changing the public
/// function shape.
pub fn parse_with_config(
  input: String,
  _config: ast.ParseConfig,
) -> Result(ast.Parsed, ast.ParseError) {
  parse(input)
}

/// Validation is exposed beside parsing but remains a separate call so author
/// configuration cannot accidentally alter syntactic parse success.
pub fn validate_symbols(
  parsed: ast.Parsed,
  config: ast.SymbolConfig,
) -> Result(ast.Parsed, ast.ValidationError) {
  validate.validate_symbols(parsed, config)
}

/// Debug strings are for demos and golden tests. They are intentionally not a
/// JSON or TypeScript contract for browser integration.
pub fn to_debug_string(parsed: ast.Parsed) -> String {
  format.to_debug_string(parsed)
}

/// Format parser output as LaTeX for browser previews. This must stay derived
/// from Torus parser output so preview rendering cannot accept syntax that the
/// evaluator would reject.
pub fn parsed_to_latex(parsed: ast.Parsed) -> String {
  latex.parsed_to_latex(parsed)
}

/// Format unit-aware parser output as LaTeX for browser previews without
/// asking MathJax to interpret the raw ASCII submission as a second parser.
pub fn parsed_quantity_to_latex(parsed: units_types.ParsedQuantity) -> String {
  latex.parsed_quantity_to_latex(parsed)
}

/// Keep parse-error formatting public so dev prototypes can display structured
/// failures without logging or inventing target-specific formatting.
pub fn parse_error_to_debug_string(error: ast.ParseError) -> String {
  format.parse_error_to_debug_string(error)
}

/// Structurally normalize parsed math without performing algebraic
/// simplification. Callers are responsible for parsing first and should inspect
/// `Normalized.original` when exact source form or spans matter.
pub fn structural_normalize(
  parsed: ast.Parsed,
) -> normalization_types.Normalized {
  normalization.structural_normalize(parsed)
}

/// Format a normalized result using the target-stable normalized debug string
/// contract. This is intended for diagnostics, golden tests, and hash input,
/// not as a learner-facing message or parser AST replacement.
pub fn normalized_to_debug_string(
  normalized: normalization_types.Normalized,
) -> String {
  normalization_format.normalized_to_debug_string(normalized)
}

/// Hash a normalized result as lowercase SHA-256 over the normalized debug
/// string. Keeping this in Gleam prevents BEAM and browser wrappers from
/// implementing duplicate hashing or formatting rules.
pub fn normalized_hash(normalized: normalization_types.Normalized) -> String {
  normalization_hash.normalized_hash(normalized)
}

/// Return the default runtime evaluation policy for normalized expression
/// evaluation. The policy is explicit so callers do not bake tangent or
/// factorial limits into browser or Elixir wrappers.
pub fn default_eval_config() -> sampling_types.EvalConfig {
  sampling_types.default_eval_config()
}

/// Return the default domain override set for deterministic sampling. Missing
/// variables are resolved by later domain code to the finite effective range
/// documented in the sampling work item.
pub fn default_domain_config() -> sampling_types.DomainConfig {
  sampling_types.default_domain_config()
}

/// Return the default deterministic sampling configuration for a caller-provided
/// seed. The seed is for a future pure Gleam PRNG and is not security-sensitive
/// randomness.
pub fn default_sampling_config(seed: Int) -> sampling_types.SamplingConfig {
  sampling_types.default_sampling_config(seed)
}

/// Return the documented default numeric tolerance for future expression
/// comparison consumers without introducing final algebraic equivalence policy.
pub fn default_expression_tolerance() -> sampling_types.Tolerance {
  sampling_types.default_expression_tolerance()
}

/// Evaluate a normalized expression with an explicit assignment and evaluation
/// config. This public boundary keeps raw parsing/normalization separate from
/// runtime math errors and returns only finite real results.
pub fn evaluate_normal_expr(
  expression: normalization_types.NormalExpr,
  assignment: sampling_types.Assignment,
  config: sampling_types.EvalConfig,
) -> Result(Float, sampling_types.RuntimeMathError) {
  sampling_evaluate.evaluate_normal_expr(expression, assignment, config)
}

/// Generate deterministic raw assignments for normalized-expression sampling.
/// This uses the shared Gleam PRNG and sampling domain rules so BEAM and browser
/// callers do not depend on target runtime randomness.
pub fn sample_assignments(
  variables: List(String),
  domains: sampling_types.DomainConfig,
  config: sampling_types.SamplingConfig,
) -> Result(List(sampling_types.SampleAssignment), sampling_types.SamplingError) {
  sampling_sample.sample_assignments(variables, domains, config)
}

/// Generate deterministic assignments that are valid for a normalized
/// expression. Expression-domain failures are retried and summarized without
/// logging raw rejected assignments.
pub fn valid_samples_for_expression(
  expression: normalization_types.NormalExpr,
  variables: List(String),
  domains: sampling_types.DomainConfig,
  sampling_config: sampling_types.SamplingConfig,
  eval_config: sampling_types.EvalConfig,
) -> Result(sampling_types.ValidSampleBatch, sampling_types.SamplingError) {
  sampling_sample.valid_samples_for_expression(
    expression,
    variables,
    domains,
    sampling_config,
    eval_config,
  )
}

/// Compare two finite numeric results with an explicit tolerance policy.
pub fn compare_numbers(
  expected: Float,
  actual: Float,
  tolerance: sampling_types.Tolerance,
) -> Result(sampling_types.ComparisonResult, sampling_types.ComparisonError) {
  sampling_tolerance.compare_numbers(expected, actual, tolerance)
}

/// Format an assignment for stable developer diagnostics.
pub fn assignment_to_debug_string(
  assignment: sampling_types.Assignment,
) -> String {
  sampling_format.assignment_to_debug_string(assignment)
}

/// Format a runtime math error for stable developer diagnostics.
pub fn runtime_error_to_debug_string(
  error: sampling_types.RuntimeMathError,
) -> String {
  sampling_format.runtime_error_to_debug_string(error)
}

/// Format a sampling error for stable developer diagnostics.
pub fn sampling_error_to_debug_string(
  error: sampling_types.SamplingError,
) -> String {
  sampling_format.sampling_error_to_debug_string(error)
}

/// Format a valid sample batch for stable developer diagnostics.
pub fn sample_batch_to_debug_string(
  batch: sampling_types.ValidSampleBatch,
) -> String {
  sampling_format.sample_batch_to_debug_string(batch)
}

/// Format numeric comparison details for stable developer diagnostics.
pub fn comparison_to_debug_string(
  result: sampling_types.ComparisonResult,
) -> String {
  sampling_format.comparison_to_debug_string(result)
}

/// Return the default algebraic equivalence policy for developer prototypes and
/// future preview surfaces. This is not wired into production grading.
pub fn default_algebraic_equivalence_config() -> algebraic_types.AlgebraicEquivalenceConfig {
  algebraic_types.default_algebraic_equivalence_config()
}

/// Check raw expression strings with the deterministic algebraic equivalence
/// primitive. This public boundary is for prototypes and future preview work;
/// production `evaluate_equality` expression mode remains unsupported.
pub fn check_algebraic_equivalence(
  expected: String,
  candidate: String,
  config: algebraic_types.AlgebraicEquivalenceConfig,
) -> algebraic_types.AlgebraicEquivalenceResult {
  algebraic.check_algebraic_equivalence(expected, candidate, config)
}

/// Check already-normalized expressions with the same algebraic equivalence
/// outcome taxonomy as the raw-string API.
pub fn check_normalized_algebraic_equivalence(
  expected: normalization_types.NormalExpr,
  candidate: normalization_types.NormalExpr,
  config: algebraic_types.AlgebraicEquivalenceConfig,
) -> algebraic_types.AlgebraicEquivalenceResult {
  algebraic.check_normalized_algebraic_equivalence(expected, candidate, config)
}

/// Format a full algebraic result for deterministic developer diagnostics.
/// The output is for tests and prototype tooling, not learner-facing feedback or
/// production telemetry, because detailed rows can contain raw assignments.
pub fn algebraic_equivalence_result_to_debug_string(
  result: algebraic_types.AlgebraicEquivalenceResult,
) -> String {
  algebraic_format.result_to_debug_string(result)
}

/// Return the default exact-form policy for callers that do not need a written
/// representation constraint. Exact-form APIs are not wired into production
/// grading in this work item.
pub fn default_exact_form_config() -> form_types.ExactFormConfig {
  form_types.default_exact_form_config()
}

/// Check a raw candidate expression against an exact-form constraint through
/// the public Torus math boundary.
///
/// This is source-form checking for prototypes and future preview surfaces; it
/// parses the candidate and inspects AST/literal metadata rather than evaluating
/// semantic equivalence.
pub fn check_exact_form(
  candidate: String,
  config: form_types.ExactFormConfig,
) -> form_types.FormCheckResult {
  exact_form.check_exact_form(candidate, config)
}

/// Run algebraic equivalence first, then exact-form checking only when semantic
/// equivalence passes.
///
/// This keeps semantic failures primary and preserves the non-production scope
/// of the current exact-form work item.
pub fn check_algebraic_equivalence_with_form(
  expected: String,
  candidate: String,
  equivalence_config: algebraic_types.AlgebraicEquivalenceConfig,
  form_config: form_types.ExactFormConfig,
) -> form_types.FormAwareAlgebraicResult {
  exact_form.check_algebraic_equivalence_with_form(
    expected,
    candidate,
    equivalence_config,
    form_config,
  )
}

/// Format standalone exact-form results for deterministic developer diagnostics.
/// This output is for tests and prototype tooling, not learner-facing feedback
/// or production telemetry.
pub fn form_check_result_to_debug_string(
  result: form_types.FormCheckResult,
) -> String {
  form_format.form_check_result_to_debug_string(result)
}

/// Format form-aware algebraic results for deterministic developer diagnostics.
/// This composes the algebraic formatter and can include raw diagnostic details,
/// so production callers should map structured results instead.
pub fn form_aware_algebraic_result_to_debug_string(
  result: form_types.FormAwareAlgebraicResult,
) -> String {
  form_format.form_aware_algebraic_result_to_debug_string(result)
}

/// Keep the default config in the public module so Torus callers do not need to
/// depend on internal AST module details for ordinary parsing.
pub fn default_parse_config() -> ast.ParseConfig {
  ast.default_parse_config()
}

/// Validate the math equality contract through the public Torus math boundary
/// so Elixir and browser callers do not depend on equality internals directly.
pub fn validate_equality_config(
  spec: types.EqualitySpec,
) -> Result(types.EqualitySpec, types.EqualityConfigError) {
  evaluate.validate_spec(spec)
}

/// Decode `equalityConfig` JSON through the public Torus math boundary. Keeping
/// JSON here avoids asking Elixir or TypeScript callers to understand Gleam's
/// internal equality modules.
pub fn decode_equality_config(
  source: String,
) -> Result(types.EqualitySpec, types.EqualityConfigError) {
  json.decode_equality_config(source)
}

/// Encode `equalityConfig` JSON through the same public boundary used for
/// decoding so golden fixtures and future storage cannot drift by runtime.
pub fn encode_equality_config(spec: types.EqualitySpec) -> String {
  json.encode_equality_config(spec)
}

/// Evaluate a submitted answer through the equality contract boundary. The
/// public result stays limited to equality outcomes and diagnostics so Torus
/// reducers remain responsible for feedback, scoring, and lifecycle decisions.
pub fn evaluate_equality(
  spec: types.EqualitySpec,
  submitted: String,
) -> types.EqualityResult {
  evaluate.evaluate(spec, submitted)
}

/// Decode production `matchConfig` JSON through the public Torus math boundary
/// so Elixir and browser callers do not depend on internal matching modules.
pub fn decode_match_config(
  source: String,
) -> Result(match_types.MatchConfig, match_types.MatchConfigError) {
  match_json.decode_match_config(source)
}

/// Encode production `matchConfig` JSON through the same public boundary used
/// for decoding so storage fixtures and browser/server callers cannot drift.
pub fn encode_match_config(config: match_types.MatchConfig) -> String {
  match_json.encode_match_config(config)
}

/// Evaluate a submitted answer through the response match contract. The result
/// contains match status and safe summary diagnostics only; activity reducers
/// remain responsible for scores and feedback.
pub fn evaluate_match(
  config: match_types.MatchConfig,
  submitted: String,
) -> match_types.MatchResult {
  match_evaluate.evaluate(config, submitted)
}

/// Return the hardcoded unit catalog version for diagnostics and cache keys.
pub fn unit_catalog_version() -> String {
  units_catalog.catalog_version()
}

/// Parse a unit expression through the shared unit parser.
pub fn parse_unit(
  source: String,
) -> Result(units_types.UnitExpr, units_types.UnitParseError) {
  units_parser.parse_unit(source)
}

/// Normalize a parsed unit expression into deterministic dimensions and scale.
pub fn normalize_unit(
  unit: units_types.UnitExpr,
) -> Result(units_types.NormalUnit, units_types.UnitNormalizeError) {
  units_normalize.normalize_unit(unit)
}

/// Parse a source string as either a pure expression or a quantity with units.
pub fn parse_quantity_or_expression(
  source: String,
) -> Result(units_types.ParsedQuantity, units_types.QuantityParseError) {
  units_quantity.parse_quantity_or_expression(source)
}

/// Validate unit-aware author configuration and normalize accepted units once.
pub fn validate_unit_config(
  config: units_types.UnitConfig,
) -> Result(units_types.ValidatedUnitConfig, List(units_types.UnitConfigError)) {
  units_config.validate_unit_config(config)
}

/// Compare expected and submitted quantity sources using unit policy and
/// existing numeric tolerance semantics.
pub fn compare_quantities(
  expected: String,
  submitted: String,
  config: units_types.UnitConfig,
  tolerance: sampling_types.Tolerance,
) -> units_types.UnitComparisonResult {
  units_compare.compare_quantities(expected, submitted, config, tolerance)
}

/// Format unit parse errors for deterministic developer diagnostics.
pub fn unit_parse_error_to_debug_string(
  error: units_types.UnitParseError,
) -> String {
  units_format.unit_parse_error_to_debug_string(error)
}

/// Format normalized units for deterministic developer diagnostics.
pub fn normal_unit_to_debug_string(unit: units_types.NormalUnit) -> String {
  units_format.normal_unit_to_debug_string(unit)
}

/// Format quantity parse results for deterministic developer diagnostics.
pub fn parsed_quantity_to_debug_string(
  parsed: units_types.ParsedQuantity,
) -> String {
  units_format.parsed_quantity_to_debug_string(parsed)
}

/// Format quantity parse errors for deterministic developer diagnostics.
pub fn quantity_parse_error_to_debug_string(
  error: units_types.QuantityParseError,
) -> String {
  units_format.quantity_parse_error_to_debug_string(error)
}

/// Format unit config errors for deterministic developer diagnostics.
pub fn unit_config_error_to_debug_string(
  error: units_types.UnitConfigError,
) -> String {
  units_format.unit_config_error_to_debug_string(error)
}

/// Format full unit comparison results for deterministic developer diagnostics.
pub fn unit_comparison_result_to_debug_string(
  result: units_types.UnitComparisonResult,
) -> String {
  units_format.unit_comparison_result_to_debug_string(result)
}
