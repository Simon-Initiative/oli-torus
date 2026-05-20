/// <reference types="./reporting.d.mts" />
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $dynamic from "../../../gleam_stdlib/gleam/dynamic.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $io from "../../../gleam_stdlib/gleam/io.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import { Ok, Error, toList, CustomType as $CustomType } from "../../gleam.mjs";
import * as $gleam_panic from "../../gleeunit/internal/gleam_panic.mjs";
import { read_file as read_file_text } from "../../gleeunit_ffi.mjs";

export class State extends $CustomType {
  constructor(passed, failed, skipped) {
    super();
    this.passed = passed;
    this.failed = failed;
    this.skipped = skipped;
  }
}
export const State$State = (passed, failed, skipped) =>
  new State(passed, failed, skipped);
export const State$isState = (value) => value instanceof State;
export const State$State$passed = (value) => value.passed;
export const State$State$0 = (value) => value.passed;
export const State$State$failed = (value) => value.failed;
export const State$State$1 = (value) => value.failed;
export const State$State$skipped = (value) => value.skipped;
export const State$State$2 = (value) => value.skipped;

export function new_state() {
  return new State(0, 0, 0);
}

function red(text) {
  return ("\u{001b}[31m" + text) + "\u{001b}[39m";
}

function yellow(text) {
  return ("\u{001b}[33m" + text) + "\u{001b}[39m";
}

function green(text) {
  return ("\u{001b}[32m" + text) + "\u{001b}[39m";
}

export function finished(state) {
  let $ = state.failed;
  if ($ === 0) {
    let $1 = state.skipped;
    if ($1 === 0) {
      let $2 = state.passed;
      if ($2 === 0) {
        $io.println("\nNo tests found!");
        return 1;
      } else {
        let message = ("\n" + $int.to_string(state.passed)) + " passed, no failures";
        $io.println(green(message));
        return 0;
      }
    } else {
      let message = ((("\n" + $int.to_string(state.passed)) + " passed, 0 failures, ") + $int.to_string(
        state.skipped,
      )) + " skipped";
      $io.println(yellow(message));
      return 1;
    }
  } else {
    let $1 = state.skipped;
    if ($1 === 0) {
      let message = ((("\n" + $int.to_string(state.passed)) + " passed, ") + $int.to_string(
        state.failed,
      )) + " failures";
      $io.println(red(message));
      return 1;
    } else {
      let message = ((((("\n" + $int.to_string(state.passed)) + " passed, ") + $int.to_string(
        state.failed,
      )) + " failures, ") + $int.to_string(state.skipped)) + " skipped";
      $io.println(red(message));
      return 1;
    }
  }
}

export function test_passed(state) {
  $io.print(green("."));
  return new State(state.passed + 1, state.failed, state.skipped);
}

function grey(text) {
  return ("\u{001b}[90m" + text) + "\u{001b}[39m";
}

function format_unknown(module, function$, error) {
  return $string.concat(
    toList([
      grey((module + ".") + function$) + "\n",
      "An unexpected error occurred:\n",
      "\n",
      ("  " + $string.inspect(error)) + "\n",
    ]),
  );
}

function cyan(text) {
  return ("\u{001b}[36m" + text) + "\u{001b}[39m";
}

function code_snippet(src, start, end) {
  let _pipe = $result.try$(
    $option.to_result(src, undefined),
    (src) => {
      return $result.try$(
        $bit_array.slice(src, start, end - start),
        (snippet) => {
          return $result.try$(
            $bit_array.to_string(snippet),
            (snippet) => {
              let snippet$1 = ((cyan(" code") + ": ") + snippet) + "\n";
              return new Ok(snippet$1);
            },
          );
        },
      );
    },
  );
  return $result.unwrap(_pipe, "");
}

function bold(text) {
  return ("\u{001b}[1m" + text) + "\u{001b}[22m";
}

function inspect_value(value) {
  let $ = value.kind;
  if ($ instanceof $gleam_panic.Literal) {
    return grey("literal");
  } else if ($ instanceof $gleam_panic.Expression) {
    let value$1 = $.value;
    return $string.inspect(value$1);
  } else {
    return grey("unevaluated");
  }
}

function assert_value(name, value) {
  return ((cyan(name) + ": ") + inspect_value(value)) + "\n";
}

function assert_info(kind) {
  if (kind instanceof $gleam_panic.BinaryOperator) {
    let left = kind.left;
    let right = kind.right;
    return $string.concat(
      toList([assert_value(" left", left), assert_value("right", right)]),
    );
  } else if (kind instanceof $gleam_panic.FunctionCall) {
    let arguments$ = kind.arguments;
    let _pipe = arguments$;
    let _pipe$1 = $list.index_map(
      _pipe,
      (e, i) => {
        let number = $string.pad_start($int.to_string(i), 5, " ");
        return assert_value(number, e);
      },
    );
    return $string.concat(_pipe$1);
  } else {
    return "";
  }
}

function format_gleam_error(error, module, function$, src) {
  let location = grey((error.file + ":") + $int.to_string(error.line));
  let $ = error.kind;
  if ($ instanceof $gleam_panic.Todo) {
    return $string.concat(
      toList([
        ((bold(yellow("todo")) + " ") + location) + "\n",
        ((((cyan(" test") + ": ") + module) + ".") + function$) + "\n",
        ((cyan(" info") + ": ") + error.message) + "\n",
      ]),
    );
  } else if ($ instanceof $gleam_panic.Panic) {
    return $string.concat(
      toList([
        ((bold(red("panic")) + " ") + location) + "\n",
        ((((cyan(" test") + ": ") + module) + ".") + function$) + "\n",
        ((cyan(" info") + ": ") + error.message) + "\n",
      ]),
    );
  } else if ($ instanceof $gleam_panic.LetAssert) {
    let start = $.start;
    let end = $.end;
    let value = $.value;
    return $string.concat(
      toList([
        ((bold(red("let assert")) + " ") + location) + "\n",
        ((((cyan(" test") + ": ") + module) + ".") + function$) + "\n",
        code_snippet(src, start, end),
        ((cyan("value") + ": ") + $string.inspect(value)) + "\n",
        ((cyan(" info") + ": ") + error.message) + "\n",
      ]),
    );
  } else {
    let start = $.start;
    let end = $.end;
    let kind = $.kind;
    return $string.concat(
      toList([
        ((bold(red("assert")) + " ") + location) + "\n",
        ((((cyan(" test") + ": ") + module) + ".") + function$) + "\n",
        code_snippet(src, start, end),
        assert_info(kind),
        ((cyan(" info") + ": ") + error.message) + "\n",
      ]),
    );
  }
}

function read_file(path) {
  let $ = read_file_text(path);
  if ($ instanceof Ok) {
    let text = $[0];
    return new Ok($bit_array.from_string(text));
  } else {
    return $;
  }
}

export function test_failed(state, module, function$, error) {
  let _block;
  let $ = $gleam_panic.from_dynamic(error);
  if ($ instanceof Ok) {
    let error$1 = $[0];
    let src = $option.from_result(read_file(error$1.file));
    _block = format_gleam_error(error$1, module, function$, src);
  } else {
    _block = format_unknown(module, function$, error);
  }
  let message = _block;
  $io.print("\n" + message);
  return new State(state.passed, state.failed + 1, state.skipped);
}

export function eunit_missing() {
  let message = bold(red("Error")) + ": EUnit libraries not found.\n\nYour Erlang installation seems to be incomplete. If you installed Erlang using\na package manager ensure that you have installed the full Erlang\ndistribution instead of a stripped-down version.\n";
  $io.print_error(message);
  return new Error(undefined);
}

export function test_skipped(state, module, function$) {
  $io.print(((("\n" + module) + ".") + function$) + yellow(" skipped"));
  return new State(state.passed, state.failed, state.skipped + 1);
}
