import gleeunit
import math/latex
import math/parser
import math/units/quantity
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn formats_core_expression_syntax_as_latex_test() {
  assert latex_for("2x + 6") == "2x + 6"
  assert latex_for("2(x + 3)") == "2\\left(x + 3\\right)"
  assert latex_for("sqrt(2)/2") == "\\frac{\\sqrt{2}}{2}"
  assert latex_for("x^2") == "x^{2}"
  assert latex_for("sin(x)") == "\\sin\\left(x\\right)"
  assert latex_for("pi") == "\\pi"
}

pub fn formats_grouping_and_associativity_without_changing_meaning_test() {
  assert latex_for("(x + 1)(x - 1)")
    == "\\left(x + 1\\right)\\left(x - 1\\right)"
  assert latex_for("x-(y+1)") == "x - \\left(y + 1\\right)"
  assert latex_for("(-x)^2") == "\\left(-x\\right)^{2}"
  assert latex_for("-x^2") == "-x^{2}"
}

pub fn formats_functions_scientific_notation_and_factorial_test() {
  assert latex_for("1.2e-3") == "1.2 \\times 10^{-3}"
  assert latex_for("abs(x - 2)") == "\\left|x - 2\\right|"
  assert latex_for("|x - 2|") == "\\left|x - 2\\right|"
  assert latex_for("log10(100)") == "\\log_{10}\\left(100\\right)"
  assert latex_for("n!") == "n!"
}

pub fn formats_quantity_inputs_without_raw_ascii_interpretation_test() {
  assert quantity_latex_for("9.8 m/s^2")
    == "9.8\\, \\frac{\\mathrm{m}}{\\mathrm{s}^{2}}"
  assert quantity_latex_for("(1 + 2) J/(mol*K)")
    == "1 + 2\\, \\frac{\\mathrm{J}}{\\mathrm{mol}\\, \\mathrm{K}}"
  assert quantity_latex_for("x + 1") == "x + 1"
}

pub fn public_api_exposes_parser_derived_latex_test() {
  let assert Ok(parsed) = parser.parse("sqrt(2)/2")
  assert torus_math.parsed_to_latex(parsed) == "\\frac{\\sqrt{2}}{2}"
}

fn latex_for(source: String) -> String {
  let assert Ok(parsed) = parser.parse(source)
  latex.parsed_to_latex(parsed)
}

fn quantity_latex_for(source: String) -> String {
  let assert Ok(parsed) = quantity.parse_quantity_or_expression(source)
  latex.parsed_quantity_to_latex(parsed)
}
