/// <reference types="./validate.d.mts" />
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import { Ok, Error, Empty as $Empty } from "../gleam.mjs";
import * as $ast from "../math/ast.mjs";

function validate_args(loop$args, loop$config) {
  while (true) {
    let args = loop$args;
    let config = loop$config;
    if (args instanceof $Empty) {
      return new Ok(undefined);
    } else {
      let first = args.head;
      let rest = args.tail;
      let $ = validate_expr(first, config);
      if ($ instanceof Ok) {
        loop$args = rest;
        loop$config = config;
      } else {
        return $;
      }
    }
  }
}

function validate_expr(loop$expr, loop$config) {
  while (true) {
    let expr = loop$expr;
    let config = loop$config;
    let $ = expr.kind;
    if ($ instanceof $ast.Num) {
      return new Ok(undefined);
    } else if ($ instanceof $ast.Var) {
      let name = $[0];
      let $1 = $list.contains(config.allowed_variables, name);
      if ($1) {
        return new Ok(undefined);
      } else {
        return new Error(new $ast.UnexpectedVariable(expr.span, name));
      }
    } else if ($ instanceof $ast.Const) {
      return new Ok(undefined);
    } else if ($ instanceof $ast.Prefix) {
      let arg = $.arg;
      loop$expr = arg;
      loop$config = config;
    } else if ($ instanceof $ast.Binary) {
      let left = $.left;
      let right = $.right;
      let $1 = validate_expr(left, config);
      if ($1 instanceof Ok) {
        loop$expr = right;
        loop$config = config;
      } else {
        return $1;
      }
    } else if ($ instanceof $ast.Call) {
      let name = $.name;
      let args = $.args;
      let $1 = $list.contains(config.allowed_functions, name);
      if ($1) {
        return validate_args(args, config);
      } else {
        return new Error(new $ast.DisallowedFunction(expr.span, name));
      }
    } else {
      let arg = $.arg;
      loop$expr = arg;
      loop$config = config;
    }
  }
}

/**
 * Validation intentionally accepts an already parsed AST. This keeps syntactic
 * parser success independent from author settings, so activities can decide
 * whether a symbol is allowed without changing what the parser recognizes.
 */
export function validate_symbols(parsed, config) {
  if (parsed instanceof $ast.Expression) {
    let expr = parsed[0];
    let $ = validate_expr(expr, config);
    if ($ instanceof Ok) {
      return new Ok(parsed);
    } else {
      return $;
    }
  } else {
    let value = parsed.value;
    let $ = validate_expr(value, config);
    if ($ instanceof Ok) {
      return new Ok(parsed);
    } else {
      return $;
    }
  }
}
