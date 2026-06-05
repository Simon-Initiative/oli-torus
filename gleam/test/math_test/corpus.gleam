/// The Phase 1 corpus is intentionally data only. Later phases will attach
/// expected ASTs and errors while keeping this shared accepted/rejected shape.
pub fn accepted_parser_inputs() -> List(String) {
  [
    "2",
    "2.0",
    "1.23e-4",
    "x",
    "2x",
    "xy",
    "2(x+3)",
    "(x+1)(x-1)",
    "2x + 6",
    "sqrt(2)/2",
    "sin(x)",
    "cos(x)",
    "tan(x)",
    "ln(x)",
    "log(x)",
    "log10(x)",
    "log2(x)",
    "abs(x)",
    "exp(x)",
    "pi",
    "e",
    "|x-2|",
    "n!",
    "2^3^4",
    "-x^2",
  ]
}

/// These cases document unsupported or malformed syntax before behavior exists.
/// Parser implementation phases should replace scaffold assertions with
/// structured error expectations for each input.
pub fn rejected_parser_inputs() -> List(String) {
  ["2^^3", "1,000", "tan x", "sqrt()", "(x+1", "|x-2", "2+"]
}

/// Precedence cases live separately so binding-power decisions are visible in
/// review before the Pratt parser is implemented.
pub fn precedence_inputs() -> List(String) {
  ["2+3*4", "2*3+4", "2^3^4", "-x^2", "(-x)^2", "2x^2", "1/2x"]
}
