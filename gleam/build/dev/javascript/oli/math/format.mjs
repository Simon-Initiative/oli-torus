/// <reference types="./format.d.mts" />
import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import * as $ast from "../math/ast.mjs";

function quote(value) {
  return ("\"" + value) + "\"";
}

function unit_to_debug_string(unit) {
  if (unit instanceof $ast.UnitAtom) {
    let symbol = unit.symbol;
    return ("UnitAtom(" + quote(symbol)) + ")";
  } else if (unit instanceof $ast.UnitMul) {
    let left = unit.left;
    let right = unit.right;
    return ((("UnitMul(" + unit_to_debug_string(left)) + ", ") + unit_to_debug_string(
      right,
    )) + ")";
  } else if (unit instanceof $ast.UnitDiv) {
    let left = unit.left;
    let right = unit.right;
    return ((("UnitDiv(" + unit_to_debug_string(left)) + ", ") + unit_to_debug_string(
      right,
    )) + ")";
  } else {
    let unit$1 = unit.unit;
    let exponent = unit.exponent;
    return ((("UnitPow(" + unit_to_debug_string(unit$1)) + ", ") + $int.to_string(
      exponent,
    )) + ")";
  }
}

function function_name_to_debug_string(name) {
  if (name instanceof $ast.Sin) {
    return "Sin";
  } else if (name instanceof $ast.Cos) {
    return "Cos";
  } else if (name instanceof $ast.Tan) {
    return "Tan";
  } else if (name instanceof $ast.Ln) {
    return "Ln";
  } else if (name instanceof $ast.Log) {
    return "Log";
  } else if (name instanceof $ast.Log10) {
    return "Log10";
  } else if (name instanceof $ast.Log2) {
    return "Log2";
  } else if (name instanceof $ast.Sqrt) {
    return "Sqrt";
  } else if (name instanceof $ast.Abs) {
    return "Abs";
  } else {
    return "Exp";
  }
}

function binary_op_to_debug_string(op) {
  if (op instanceof $ast.Add) {
    return "Add";
  } else if (op instanceof $ast.Subtract) {
    return "Subtract";
  } else if (op instanceof $ast.Multiply) {
    let $ = op.style;
    if ($ instanceof $ast.ExplicitMultiply) {
      return "Mul[explicit]";
    } else {
      return "Mul[implicit]";
    }
  } else if (op instanceof $ast.Divide) {
    return "Divide";
  } else {
    return "Power";
  }
}

function prefix_op_to_debug_string(op) {
  if (op instanceof $ast.Negate) {
    return "Negate";
  } else {
    return "Positive";
  }
}

function constant_to_debug_string(constant) {
  if (constant instanceof $ast.Pi) {
    return "Pi";
  } else {
    return "Euler";
  }
}

function expr_to_debug_string(expr) {
  let $ = expr.kind;
  if ($ instanceof $ast.Num) {
    let literal = $[0];
    return ("Num(" + quote(literal.raw)) + ")";
  } else if ($ instanceof $ast.Var) {
    let name = $[0];
    return ("Var(" + quote(name)) + ")";
  } else if ($ instanceof $ast.Const) {
    let constant = $[0];
    return ("Const(" + constant_to_debug_string(constant)) + ")";
  } else if ($ instanceof $ast.Prefix) {
    let op = $.op;
    let arg = $.arg;
    return ((("Prefix(" + prefix_op_to_debug_string(op)) + ", ") + expr_to_debug_string(
      arg,
    )) + ")";
  } else if ($ instanceof $ast.Binary) {
    let op = $.op;
    let left = $.left;
    let right = $.right;
    return ((((binary_op_to_debug_string(op) + "(") + expr_to_debug_string(left)) + ", ") + expr_to_debug_string(
      right,
    )) + ")";
  } else if ($ instanceof $ast.Call) {
    let name = $.name;
    let args = $.args;
    return ((("Call(" + function_name_to_debug_string(name)) + ", [") + $string.join(
      $list.map(args, expr_to_debug_string),
      ", ",
    )) + "])";
  } else {
    let arg = $.arg;
    return ("Factorial(" + expr_to_debug_string(arg)) + ")";
  }
}

/**
 * Debug formatting is deliberately separate from JSON serialization. These
 * strings are stable golden-test and demo output, not a browser data contract
 * or an evaluator interchange format.
 */
export function to_debug_string(parsed) {
  if (parsed instanceof $ast.Expression) {
    let expr = parsed[0];
    return ("Expression(" + expr_to_debug_string(expr)) + ")";
  } else {
    let value = parsed.value;
    let unit = parsed.unit;
    return ((("Quantity(" + expr_to_debug_string(value)) + ", ") + unit_to_debug_string(
      unit,
    )) + ")";
  }
}

function span_to_debug_string(span) {
  return ((("Span(" + $int.to_string(span.start)) + ",") + $int.to_string(
    span.end,
  )) + ")";
}

export function parse_error_to_debug_string(error) {
  if (error instanceof $ast.UnexpectedToken) {
    let span = error.span;
    let expected = error.expected;
    let found = error.found;
    return ((((("UnexpectedToken(" + span_to_debug_string(span)) + ", expected=[") + $string.join(
      expected,
      ",",
    )) + "], found=") + quote(found)) + ")";
  } else if (error instanceof $ast.UnexpectedEnd) {
    let expected = error.expected;
    return ("UnexpectedEnd(expected=[" + $string.join(expected, ",")) + "])";
  } else if (error instanceof $ast.InvalidNumber) {
    let span = error.span;
    let raw = error.raw;
    return ((("InvalidNumber(" + span_to_debug_string(span)) + ", raw=") + quote(
      raw,
    )) + ")";
  } else if (error instanceof $ast.UnsupportedCharacter) {
    let span = error.span;
    let raw = error.raw;
    return ((("UnsupportedCharacter(" + span_to_debug_string(span)) + ", raw=") + quote(
      raw,
    )) + ")";
  } else if (error instanceof $ast.UnsupportedFunction) {
    let span = error.span;
    let name = error.name;
    return ((("UnsupportedFunction(" + span_to_debug_string(span)) + ", name=") + quote(
      name,
    )) + ")";
  } else if (error instanceof $ast.FunctionRequiresParentheses) {
    let span = error.span;
    let name = error.name;
    return ((("FunctionRequiresParentheses(" + span_to_debug_string(span)) + ", name=") + quote(
      name,
    )) + ")";
  } else if (error instanceof $ast.UnclosedParenthesis) {
    let opened_at = error.opened_at;
    return ("UnclosedParenthesis(opened_at=" + span_to_debug_string(opened_at)) + ")";
  } else if (error instanceof $ast.UnclosedAbsoluteValue) {
    let opened_at = error.opened_at;
    return ("UnclosedAbsoluteValue(opened_at=" + span_to_debug_string(opened_at)) + ")";
  } else {
    let span = error.span;
    return ("TrailingInput(" + span_to_debug_string(span)) + ")";
  }
}
