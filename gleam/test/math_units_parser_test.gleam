import gleam/list
import gleeunit
import math/ast
import math/units/parser
import math/units/types

pub fn main() {
  gleeunit.main()
}

pub fn parses_required_simple_and_compound_units_test() {
  assert parser.parse_unit("m") == Ok(atom("m"))
  assert parser.parse_unit("cm") == Ok(atom("cm"))
  assert parser.parse_unit("s") == Ok(atom("s"))
  assert parser.parse_unit("m/s") == Ok(div(atom("m"), atom("s")))
  assert parser.parse_unit("m/s^2") == Ok(div(atom("m"), pow(atom("s"), 2)))
  assert parser.parse_unit("cm/s^2") == Ok(div(atom("cm"), pow(atom("s"), 2)))
  assert parser.parse_unit("kg*m/s^2")
    == Ok(div(mul(atom("kg"), atom("m")), pow(atom("s"), 2)))
  assert parser.parse_unit("km/hr") == Ok(div(atom("km"), atom("hr")))
  assert parser.parse_unit("N") == Ok(atom("N"))
}

pub fn parses_grouped_signed_power_and_unicode_catalog_atoms_test() {
  assert parser.parse_unit("J/(mol*K)")
    == Ok(div(atom("J"), mul(atom("mol"), atom("K"))))
  assert parser.parse_unit("(m/s)^-2") == Ok(pow(div(atom("m"), atom("s")), -2))
  assert parser.parse_unit("m^+2") == Ok(pow(atom("m"), 2))
  assert parser.parse_unit("µm") == Ok(atom("µm"))
  assert parser.parse_unit("Å") == Ok(atom("Å"))
  assert parser.parse_unit("Ω") == Ok(atom("Ω"))
  assert parser.parse_unit("kΩ") == Ok(atom("kΩ"))
  assert parser.parse_unit("MΩ") == Ok(atom("MΩ"))
}

pub fn parses_common_compound_presets_through_grammar_test() {
  let presets = [
    "m/s",
    "m/s^2",
    "cm/s",
    "cm/s^2",
    "km/hr",
    "mi/hr",
    "mph",
    "ft/s",
    "ft/s^2",
    "kg*m/s^2",
    "N",
    "N*m",
    "J",
    "J/s",
    "W",
    "Pa",
    "kPa",
    "atm",
    "bar",
    "torr",
    "mmHg",
    "mol/L",
    "M",
    "mM",
    "uM",
    "g/L",
    "mg/L",
    "g/mL",
    "kg/m^3",
    "J/mol",
    "kJ/mol",
    "cal/mol",
    "kcal/mol",
    "J/(mol*K)",
    "L*atm",
  ]

  list.each(presets, fn(source) {
    let assert Ok(_) = parser.parse_unit(source)
    Nil
  })
}

pub fn rejects_empty_unsupported_and_malformed_units_test() {
  assert parser.parse_unit("") == Error(types.EmptyUnitExpression)
  assert parser.parse_unit("   ") == Error(types.EmptyUnitExpression)
  assert parser.parse_unit("parsec")
    == Error(types.UnsupportedUnitAtom(span: span(0, 6), symbol: "parsec"))
  assert parser.parse_unit("m//s")
    == Error(types.UnexpectedUnitToken(
      span: span(2, 3),
      expected: ["unit atom", "("],
      found: "/",
    ))
  assert parser.parse_unit("m^")
    == Error(types.MalformedUnitPower(span: span(1, 2)))
  assert parser.parse_unit("m^x")
    == Error(types.MalformedUnitPower(span: span(2, 3)))
  assert parser.parse_unit("m/")
    == Error(types.UnexpectedUnitToken(
      span: span(1, 2),
      expected: ["unit atom", "("],
      found: "end of input",
    ))
  assert parser.parse_unit("(m/s")
    == Error(types.UnclosedUnitParenthesis(opened_at: span(0, 1)))
  assert parser.parse_unit("m s")
    == Error(types.TrailingUnitInput(span: span(2, 3)))
  assert parser.parse_unit("m%")
    == Error(types.TrailingUnitInput(span: span(1, 2)))
}

fn atom(symbol: String) -> types.UnitExpr {
  types.UnitAtom(symbol: symbol)
}

fn mul(left: types.UnitExpr, right: types.UnitExpr) -> types.UnitExpr {
  types.UnitMul(left: left, right: right)
}

fn div(left: types.UnitExpr, right: types.UnitExpr) -> types.UnitExpr {
  types.UnitDiv(left: left, right: right)
}

fn pow(unit: types.UnitExpr, exponent: Int) -> types.UnitExpr {
  types.UnitPow(unit: unit, exponent: exponent)
}

fn span(start: Int, end: Int) -> ast.Span {
  ast.Span(start: start, end: end)
}
