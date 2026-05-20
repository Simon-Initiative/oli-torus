/// <reference types="./lexer.d.mts" />
import * as $float from "../../gleam_stdlib/gleam/float.mjs";
import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import { None, Some } from "../../gleam_stdlib/gleam/option.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import { Ok, Error, toList, Empty as $Empty, prepend as listPrepend } from "../gleam.mjs";
import * as $ast from "../math/ast.mjs";
import * as $token from "../math/token.mjs";

function symbol_for(raw) {
  if (raw === "+") {
    return new Ok(new $token.Plus());
  } else if (raw === "-") {
    return new Ok(new $token.Minus());
  } else if (raw === "*") {
    return new Ok(new $token.Star());
  } else if (raw === "/") {
    return new Ok(new $token.Slash());
  } else if (raw === "^") {
    return new Ok(new $token.Caret());
  } else if (raw === "(") {
    return new Ok(new $token.LParen());
  } else if (raw === ")") {
    return new Ok(new $token.RParen());
  } else if (raw === "|") {
    return new Ok(new $token.Bar());
  } else if (raw === "!") {
    return new Ok(new $token.Bang());
  } else if (raw === ",") {
    return new Ok(new $token.Comma());
  } else {
    return new Error(undefined);
  }
}

function join_chars(chars) {
  return $string.join(chars, "");
}

function grapheme_code(raw) {
  let $ = $string.to_utf_codepoints(raw);
  if ($ instanceof $Empty) {
    return -1;
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      let codepoint = $.head;
      return $string.utf_codepoint_to_int(codepoint);
    } else {
      return -1;
    }
  }
}

function is_digit(raw) {
  let $ = $string.to_graphemes(raw);
  if ($ instanceof $Empty) {
    return false;
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      let grapheme = $.head;
      let code = grapheme_code(grapheme);
      return (code >= 48) && (code <= 57);
    } else {
      return false;
    }
  }
}

function is_alpha(raw) {
  let $ = $string.to_graphemes(raw);
  if ($ instanceof $Empty) {
    return false;
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      let grapheme = $.head;
      let code = grapheme_code(grapheme);
      return ((code >= 65) && (code <= 90)) || ((code >= 97) && (code <= 122));
    } else {
      return false;
    }
  }
}

function is_word_continue(raw) {
  return is_alpha(raw) || is_digit(raw);
}

function take_while(loop$chars, loop$offset, loop$predicate, loop$acc) {
  while (true) {
    let chars = loop$chars;
    let offset = loop$offset;
    let predicate = loop$predicate;
    let acc = loop$acc;
    if (chars instanceof $Empty) {
      return [$list.reverse(acc), chars, offset];
    } else {
      let first = chars.head;
      let rest = chars.tail;
      let $ = predicate(first);
      if ($) {
        loop$chars = rest;
        loop$offset = offset + 1;
        loop$predicate = predicate;
        loop$acc = listPrepend(first, acc);
      } else {
        return [$list.reverse(acc), chars, offset];
      }
    }
  }
}

function read_leading_dot_error(chars, start) {
  if (chars instanceof $Empty) {
    return new $ast.UnsupportedCharacter(new $ast.Span(start, start + 1), ".");
  } else {
    let $ = chars.head;
    if ($ === ".") {
      let rest = chars.tail;
      let $1 = take_while(rest, start + 1, is_digit, toList([]));
      let fraction;
      let end_offset;
      fraction = $1[0];
      end_offset = $1[2];
      if (fraction instanceof $Empty) {
        return new $ast.UnsupportedCharacter(
          new $ast.Span(start, start + 1),
          ".",
        );
      } else {
        return new $ast.InvalidNumber(
          new $ast.Span(start, end_offset),
          join_chars(listPrepend(".", fraction)),
        );
      }
    } else {
      return new $ast.UnsupportedCharacter(new $ast.Span(start, start + 1), ".");
    }
  }
}

function normalize_scientific_for_parse(raw) {
  let normalized_marker = $string.replace(raw, "E", "e");
  let $ = $string.contains(normalized_marker, ".");
  if ($) {
    return normalized_marker;
  } else {
    let $1 = $string.split_once(normalized_marker, "e");
    if ($1 instanceof Ok) {
      let mantissa = $1[0][0];
      let exponent = $1[0][1];
      return (mantissa + ".0e") + exponent;
    } else {
      return normalized_marker;
    }
  }
}

function parse_number_value(raw, notation) {
  if (notation instanceof $ast.IntegerNotation) {
    let $ = $int.parse(raw);
    if ($ instanceof Ok) {
      let value = $[0];
      return new Ok($int.to_float(value));
    } else {
      return $;
    }
  } else if (notation instanceof $ast.DecimalNotation) {
    return $float.parse(raw);
  } else {
    let _pipe = normalize_scientific_for_parse(raw);
    return $float.parse(_pipe);
  }
}

function finish_number(raw, rest, end_offset, start, notation, decimal_places) {
  let $ = parse_number_value(raw, notation);
  if ($ instanceof Ok) {
    let value = $[0];
    return new Ok(
      [
        new $ast.NumberLiteral(raw, value, notation, decimal_places),
        rest,
        end_offset,
      ],
    );
  } else {
    return new Error(
      new $ast.InvalidNumber(new $ast.Span(start, end_offset), raw),
    );
  }
}

function invalid_exponent(prefix, marker, sign, start, end_offset) {
  return new Error(
    new $ast.InvalidNumber(
      new $ast.Span(start, end_offset),
      (prefix + marker) + sign,
    ),
  );
}

function unsupported_comma(offset) {
  return new $ast.UnsupportedCharacter(new $ast.Span(offset, offset + 1), ",");
}

function read_exponent(
  prefix,
  marker,
  after_marker,
  marker_offset,
  start,
  decimal_places
) {
  let _block;
  if (after_marker instanceof $Empty) {
    _block = ["", after_marker, marker_offset + 1];
  } else {
    let $1 = after_marker.head;
    if ($1 === "+") {
      let rest = after_marker.tail;
      _block = ["+", rest, marker_offset + 2];
    } else if ($1 === "-") {
      let rest = after_marker.tail;
      _block = ["-", rest, marker_offset + 2];
    } else {
      _block = ["", after_marker, marker_offset + 1];
    }
  }
  let $ = _block;
  let sign;
  let exponent_chars;
  let exponent_start;
  sign = $[0];
  exponent_chars = $[1];
  exponent_start = $[2];
  if (exponent_chars instanceof $Empty) {
    return invalid_exponent(prefix, marker, sign, start, exponent_start);
  } else {
    let first_digit = exponent_chars.head;
    let $1 = is_digit(first_digit);
    if ($1) {
      let $2 = take_while(exponent_chars, exponent_start, is_digit, toList([]));
      let exponent_digits;
      let rest;
      let end_offset;
      exponent_digits = $2[0];
      rest = $2[1];
      end_offset = $2[2];
      if (rest instanceof $Empty) {
        return finish_number(
          ((prefix + marker) + sign) + join_chars(exponent_digits),
          rest,
          end_offset,
          start,
          new $ast.ScientificNotation(),
          decimal_places,
        );
      } else {
        let $3 = rest.head;
        if ($3 === ",") {
          return new Error(unsupported_comma(end_offset));
        } else {
          return finish_number(
            ((prefix + marker) + sign) + join_chars(exponent_digits),
            rest,
            end_offset,
            start,
            new $ast.ScientificNotation(),
            decimal_places,
          );
        }
      }
    } else {
      return invalid_exponent(prefix, marker, sign, start, exponent_start);
    }
  }
}

function invalid_decimal(whole, start, end_offset) {
  return new Error(
    new $ast.InvalidNumber(
      new $ast.Span(start, end_offset),
      join_chars($list.append(whole, toList(["."]))),
    ),
  );
}

function read_number_after_mantissa(
  raw_prefix,
  rest,
  current_offset,
  start,
  notation,
  decimal_places
) {
  if (rest instanceof $Empty) {
    return finish_number(
      raw_prefix,
      rest,
      current_offset,
      start,
      notation,
      decimal_places,
    );
  } else {
    let $ = rest.head;
    if ($ === ",") {
      return new Error(unsupported_comma(current_offset));
    } else if ($ === "e") {
      let after_marker = rest.tail;
      return read_exponent(
        raw_prefix,
        "e",
        after_marker,
        current_offset,
        start,
        decimal_places,
      );
    } else if ($ === "E") {
      let after_marker = rest.tail;
      return read_exponent(
        raw_prefix,
        "E",
        after_marker,
        current_offset,
        start,
        decimal_places,
      );
    } else {
      return finish_number(
        raw_prefix,
        rest,
        current_offset,
        start,
        notation,
        decimal_places,
      );
    }
  }
}

function read_decimal(whole, after_dot, start, dot_offset) {
  let fraction_start = dot_offset + 1;
  if (after_dot instanceof $Empty) {
    return invalid_decimal(whole, start, fraction_start);
  } else {
    let first_fraction = after_dot.head;
    let $ = is_digit(first_fraction);
    if ($) {
      let $1 = take_while(after_dot, fraction_start, is_digit, toList([]));
      let fraction;
      let rest_after_fraction;
      let after_fraction;
      fraction = $1[0];
      rest_after_fraction = $1[1];
      after_fraction = $1[2];
      let raw_prefix = join_chars(
        $list.append($list.append(whole, toList(["."])), fraction),
      );
      return read_number_after_mantissa(
        raw_prefix,
        rest_after_fraction,
        after_fraction,
        start,
        new $ast.DecimalNotation(),
        new Some($list.length(fraction)),
      );
    } else {
      return invalid_decimal(whole, start, fraction_start);
    }
  }
}

function read_number(chars, start) {
  let $ = take_while(chars, start, is_digit, toList([]));
  let whole;
  let rest;
  let after_whole;
  whole = $[0];
  rest = $[1];
  after_whole = $[2];
  if (rest instanceof $Empty) {
    return finish_number(
      join_chars(whole),
      rest,
      after_whole,
      start,
      new $ast.IntegerNotation(),
      new None(),
    );
  } else {
    let $1 = rest.head;
    if ($1 === ",") {
      return new Error(unsupported_comma(after_whole));
    } else if ($1 === ".") {
      let after_dot = rest.tail;
      return read_decimal(whole, after_dot, start, after_whole);
    } else if ($1 === "e") {
      let after_marker = rest.tail;
      return read_exponent(
        join_chars(whole),
        "e",
        after_marker,
        after_whole,
        start,
        new Some(0),
      );
    } else if ($1 === "E") {
      let after_marker = rest.tail;
      return read_exponent(
        join_chars(whole),
        "E",
        after_marker,
        after_whole,
        start,
        new Some(0),
      );
    } else {
      return finish_number(
        join_chars(whole),
        rest,
        after_whole,
        start,
        new $ast.IntegerNotation(),
        new None(),
      );
    }
  }
}

function is_whitespace(raw) {
  return (((raw === " ") || (raw === "\n")) || (raw === "\t")) || (raw === "\r");
}

function lex_symbol(chars, first, offset, leading_space, acc) {
  if (chars instanceof $Empty) {
    return new Error(
      new $ast.UnsupportedCharacter(new $ast.Span(offset, offset + 1), first),
    );
  } else {
    let rest = chars.tail;
    let $ = symbol_for(first);
    if ($ instanceof Ok) {
      let symbol = $[0];
      let span = new $ast.Span(offset, offset + 1);
      let next = new $token.SymbolToken(symbol, span, leading_space);
      return do_lex(rest, offset + 1, false, listPrepend(next, acc));
    } else {
      return new Error(
        new $ast.UnsupportedCharacter(new $ast.Span(offset, offset + 1), first),
      );
    }
  }
}

function lex_word_or_symbol(chars, first, offset, leading_space, acc) {
  let $ = is_alpha(first);
  if ($) {
    let $1 = take_while(chars, offset, is_word_continue, toList([]));
    let raw_chars;
    let rest;
    let next_offset;
    raw_chars = $1[0];
    rest = $1[1];
    next_offset = $1[2];
    let span = new $ast.Span(offset, next_offset);
    let next = new $token.WordToken(join_chars(raw_chars), span, leading_space);
    return do_lex(rest, next_offset, false, listPrepend(next, acc));
  } else {
    return lex_symbol(chars, first, offset, leading_space, acc);
  }
}

function lex_number(chars, offset, leading_space, acc) {
  let $ = read_number(chars, offset);
  if ($ instanceof Ok) {
    let literal = $[0][0];
    let rest = $[0][1];
    let next_offset = $[0][2];
    let span = new $ast.Span(offset, next_offset);
    let next = new $token.NumberToken(literal, span, leading_space);
    return do_lex(rest, next_offset, false, listPrepend(next, acc));
  } else {
    return $;
  }
}

function lex_non_whitespace(chars, first, offset, leading_space, acc) {
  let $ = is_digit(first);
  if ($) {
    return lex_number(chars, offset, leading_space, acc);
  } else {
    if (first === ".") {
      return new Error(read_leading_dot_error(chars, offset));
    } else {
      return lex_word_or_symbol(chars, first, offset, leading_space, acc);
    }
  }
}

function do_lex(loop$chars, loop$offset, loop$leading_space, loop$acc) {
  while (true) {
    let chars = loop$chars;
    let offset = loop$offset;
    let leading_space = loop$leading_space;
    let acc = loop$acc;
    if (chars instanceof $Empty) {
      return new Ok($list.reverse(acc));
    } else {
      let first = chars.head;
      let rest = chars.tail;
      let $ = is_whitespace(first);
      if ($) {
        loop$chars = rest;
        loop$offset = offset + 1;
        loop$leading_space = true;
        loop$acc = acc;
      } else {
        return lex_non_whitespace(chars, first, offset, leading_space, acc);
      }
    }
  }
}

/**
 * Lexing is the first place we make syntax commitments, so it keeps the rules
 * strict and explicit. Later parser phases can depend on tokens having stable
 * spans, number metadata, and whitespace-boundary information.
 */
export function lex(input) {
  return do_lex($string.to_graphemes(input), 0, false, toList([]));
}
