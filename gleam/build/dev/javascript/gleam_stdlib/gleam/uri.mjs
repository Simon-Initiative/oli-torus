/// <reference types="./uri.d.mts" />
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  prepend as listPrepend,
  CustomType as $CustomType,
  isEqual,
} from "../gleam.mjs";
import * as $int from "../gleam/int.mjs";
import * as $list from "../gleam/list.mjs";
import * as $option from "../gleam/option.mjs";
import { None, Some } from "../gleam/option.mjs";
import * as $string from "../gleam/string.mjs";
import * as $string_tree from "../gleam/string_tree.mjs";
import {
  pop_codeunit,
  string_codeunit_slice as codeunit_slice,
  parse_query,
  percent_encode,
  percent_decode,
} from "../gleam_stdlib.mjs";

export { parse_query, percent_decode, percent_encode };

export class Uri extends $CustomType {
  constructor(scheme, userinfo, host, port, path, query, fragment) {
    super();
    this.scheme = scheme;
    this.userinfo = userinfo;
    this.host = host;
    this.port = port;
    this.path = path;
    this.query = query;
    this.fragment = fragment;
  }
}
export const Uri$Uri = (scheme, userinfo, host, port, path, query, fragment) =>
  new Uri(scheme, userinfo, host, port, path, query, fragment);
export const Uri$isUri = (value) => value instanceof Uri;
export const Uri$Uri$scheme = (value) => value.scheme;
export const Uri$Uri$0 = (value) => value.scheme;
export const Uri$Uri$userinfo = (value) => value.userinfo;
export const Uri$Uri$1 = (value) => value.userinfo;
export const Uri$Uri$host = (value) => value.host;
export const Uri$Uri$2 = (value) => value.host;
export const Uri$Uri$port = (value) => value.port;
export const Uri$Uri$3 = (value) => value.port;
export const Uri$Uri$path = (value) => value.path;
export const Uri$Uri$4 = (value) => value.path;
export const Uri$Uri$query = (value) => value.query;
export const Uri$Uri$5 = (value) => value.query;
export const Uri$Uri$fragment = (value) => value.fragment;
export const Uri$Uri$6 = (value) => value.fragment;

/**
 * Constant representing an empty URI, equivalent to "".
 *
 * ## Examples
 *
 * ```gleam
 * assert Uri(..empty, scheme: Some("https"), host: Some("example.com"))
 *   == Uri(
 *     scheme: Some("https"),
 *     userinfo: None,
 *     host: Some("example.com"),
 *     port: None,
 *     path: "",
 *     query: None,
 *     fragment: None,
 *   )
 * ```
 */
export const empty = /* @__PURE__ */ new Uri(
  /* @__PURE__ */ new None(),
  /* @__PURE__ */ new None(),
  /* @__PURE__ */ new None(),
  /* @__PURE__ */ new None(),
  "",
  /* @__PURE__ */ new None(),
  /* @__PURE__ */ new None(),
);

function parse_fragment(rest, pieces) {
  return new Ok(
    new Uri(
      pieces.scheme,
      pieces.userinfo,
      pieces.host,
      pieces.port,
      pieces.path,
      pieces.query,
      new Some(rest),
    ),
  );
}

function parse_query_with_question_mark_loop(
  loop$original,
  loop$uri_string,
  loop$pieces,
  loop$size
) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size = loop$size;
    if (uri_string.charCodeAt(0) === 35) {
      if (size === 0) {
        let rest = uri_string.slice(1);
        return parse_fragment(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let query = codeunit_slice(original, 0, size);
        let pieces$1 = new Uri(
          pieces.scheme,
          pieces.userinfo,
          pieces.host,
          pieces.port,
          pieces.path,
          new Some(query),
          pieces.fragment,
        );
        return parse_fragment(rest, pieces$1);
      }
    } else if (uri_string === "") {
      return new Ok(
        new Uri(
          pieces.scheme,
          pieces.userinfo,
          pieces.host,
          pieces.port,
          pieces.path,
          new Some(original),
          pieces.fragment,
        ),
      );
    } else {
      let $ = pop_codeunit(uri_string);
      let rest;
      rest = $[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size + 1;
    }
  }
}

function parse_query_with_question_mark(uri_string, pieces) {
  return parse_query_with_question_mark_loop(uri_string, uri_string, pieces, 0);
}

function parse_path_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size = loop$size;
    let $ = uri_string.charCodeAt(0);
    if ($ === 63) {
      let rest = uri_string.slice(1);
      let path = codeunit_slice(original, 0, size);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        pieces.host,
        pieces.port,
        path,
        pieces.query,
        pieces.fragment,
      );
      return parse_query_with_question_mark(rest, pieces$1);
    } else if ($ === 35) {
      let rest = uri_string.slice(1);
      let path = codeunit_slice(original, 0, size);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        pieces.host,
        pieces.port,
        path,
        pieces.query,
        pieces.fragment,
      );
      return parse_fragment(rest, pieces$1);
    } else if (uri_string === "") {
      return new Ok(
        new Uri(
          pieces.scheme,
          pieces.userinfo,
          pieces.host,
          pieces.port,
          original,
          pieces.query,
          pieces.fragment,
        ),
      );
    } else {
      let $1 = pop_codeunit(uri_string);
      let rest;
      rest = $1[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size + 1;
    }
  }
}

function parse_path(uri_string, pieces) {
  return parse_path_loop(uri_string, uri_string, pieces, 0);
}

function parse_port_loop(loop$uri_string, loop$pieces, loop$port) {
  while (true) {
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let port = loop$port;
    let $ = uri_string.charCodeAt(0);
    if ($ === 48) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10;
    } else if ($ === 49) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 1;
    } else if ($ === 50) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 2;
    } else if ($ === 51) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 3;
    } else if ($ === 52) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 4;
    } else if ($ === 53) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 5;
    } else if ($ === 54) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 6;
    } else if ($ === 55) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 7;
    } else if ($ === 56) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 8;
    } else if ($ === 57) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 9;
    } else if ($ === 63) {
      let rest = uri_string.slice(1);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        pieces.host,
        new Some(port),
        pieces.path,
        pieces.query,
        pieces.fragment,
      );
      return parse_query_with_question_mark(rest, pieces$1);
    } else if ($ === 35) {
      let rest = uri_string.slice(1);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        pieces.host,
        new Some(port),
        pieces.path,
        pieces.query,
        pieces.fragment,
      );
      return parse_fragment(rest, pieces$1);
    } else if ($ === 47) {
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        pieces.host,
        new Some(port),
        pieces.path,
        pieces.query,
        pieces.fragment,
      );
      return parse_path(uri_string, pieces$1);
    } else if (uri_string === "") {
      return new Ok(
        new Uri(
          pieces.scheme,
          pieces.userinfo,
          pieces.host,
          new Some(port),
          pieces.path,
          pieces.query,
          pieces.fragment,
        ),
      );
    } else {
      return new Error(undefined);
    }
  }
}

function parse_port(uri_string, pieces) {
  let $ = uri_string.charCodeAt(0);
  if (uri_string.startsWith(":0")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 0);
  } else if (uri_string.startsWith(":1")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 1);
  } else if (uri_string.startsWith(":2")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 2);
  } else if (uri_string.startsWith(":3")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 3);
  } else if (uri_string.startsWith(":4")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 4);
  } else if (uri_string.startsWith(":5")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 5);
  } else if (uri_string.startsWith(":6")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 6);
  } else if (uri_string.startsWith(":7")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 7);
  } else if (uri_string.startsWith(":8")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 8);
  } else if (uri_string.startsWith(":9")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 9);
  } else if (uri_string === ":") {
    return new Ok(pieces);
  } else if (uri_string === "") {
    return new Ok(pieces);
  } else if ($ === 63) {
    let rest = uri_string.slice(1);
    return parse_query_with_question_mark(rest, pieces);
  } else if (uri_string.startsWith(":?")) {
    let rest = uri_string.slice(2);
    return parse_query_with_question_mark(rest, pieces);
  } else if ($ === 35) {
    let rest = uri_string.slice(1);
    return parse_fragment(rest, pieces);
  } else if (uri_string.startsWith(":#")) {
    let rest = uri_string.slice(2);
    return parse_fragment(rest, pieces);
  } else if ($ === 47) {
    return parse_path(uri_string, pieces);
  } else if ($ === 58) {
    let rest = uri_string.slice(1);
    if (rest.charCodeAt(0) === 47) {
      return parse_path(rest, pieces);
    } else {
      return new Error(undefined);
    }
  } else {
    return new Error(undefined);
  }
}

function parse_host_outside_of_brackets_loop(
  loop$original,
  loop$uri_string,
  loop$pieces,
  loop$size
) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size = loop$size;
    let $ = uri_string.charCodeAt(0);
    if (uri_string === "") {
      return new Ok(
        new Uri(
          pieces.scheme,
          pieces.userinfo,
          new Some(original),
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment,
        ),
      );
    } else if ($ === 58) {
      let host = codeunit_slice(original, 0, size);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        new Some(host),
        pieces.port,
        pieces.path,
        pieces.query,
        pieces.fragment,
      );
      return parse_port(uri_string, pieces$1);
    } else if ($ === 47) {
      let host = codeunit_slice(original, 0, size);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        new Some(host),
        pieces.port,
        pieces.path,
        pieces.query,
        pieces.fragment,
      );
      return parse_path(uri_string, pieces$1);
    } else if ($ === 63) {
      let rest = uri_string.slice(1);
      let host = codeunit_slice(original, 0, size);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        new Some(host),
        pieces.port,
        pieces.path,
        pieces.query,
        pieces.fragment,
      );
      return parse_query_with_question_mark(rest, pieces$1);
    } else if ($ === 35) {
      let rest = uri_string.slice(1);
      let host = codeunit_slice(original, 0, size);
      let pieces$1 = new Uri(
        pieces.scheme,
        pieces.userinfo,
        new Some(host),
        pieces.port,
        pieces.path,
        pieces.query,
        pieces.fragment,
      );
      return parse_fragment(rest, pieces$1);
    } else {
      let $1 = pop_codeunit(uri_string);
      let rest;
      rest = $1[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size + 1;
    }
  }
}

function parse_host_outside_of_brackets(uri_string, pieces) {
  return parse_host_outside_of_brackets_loop(uri_string, uri_string, pieces, 0);
}

function is_valid_host_within_brackets_char(char) {
  return (((((48 >= char) && (char <= 57)) || ((65 >= char) && (char <= 90))) || ((97 >= char) && (char <= 122))) || (char === 58)) || (char === 46);
}

function parse_host_within_brackets_loop(
  loop$original,
  loop$uri_string,
  loop$pieces,
  loop$size
) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size = loop$size;
    let $ = uri_string.charCodeAt(0);
    if (uri_string === "") {
      return new Ok(
        new Uri(
          pieces.scheme,
          pieces.userinfo,
          new Some(uri_string),
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment,
        ),
      );
    } else if ($ === 93) {
      if (size === 0) {
        let rest = uri_string.slice(1);
        return parse_port(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let host = codeunit_slice(original, 0, size + 1);
        let pieces$1 = new Uri(
          pieces.scheme,
          pieces.userinfo,
          new Some(host),
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment,
        );
        return parse_port(rest, pieces$1);
      }
    } else if ($ === 47) {
      if (size === 0) {
        return parse_path(uri_string, pieces);
      } else {
        let host = codeunit_slice(original, 0, size);
        let pieces$1 = new Uri(
          pieces.scheme,
          pieces.userinfo,
          new Some(host),
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment,
        );
        return parse_path(uri_string, pieces$1);
      }
    } else if ($ === 63) {
      if (size === 0) {
        let rest = uri_string.slice(1);
        return parse_query_with_question_mark(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let host = codeunit_slice(original, 0, size);
        let pieces$1 = new Uri(
          pieces.scheme,
          pieces.userinfo,
          new Some(host),
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment,
        );
        return parse_query_with_question_mark(rest, pieces$1);
      }
    } else if ($ === 35) {
      if (size === 0) {
        let rest = uri_string.slice(1);
        return parse_fragment(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let host = codeunit_slice(original, 0, size);
        let pieces$1 = new Uri(
          pieces.scheme,
          pieces.userinfo,
          new Some(host),
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment,
        );
        return parse_fragment(rest, pieces$1);
      }
    } else {
      let $1 = pop_codeunit(uri_string);
      let char;
      let rest;
      char = $1[0];
      rest = $1[1];
      let $2 = is_valid_host_within_brackets_char(char);
      if ($2) {
        loop$original = original;
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$size = size + 1;
      } else {
        return parse_host_outside_of_brackets_loop(
          original,
          original,
          pieces,
          0,
        );
      }
    }
  }
}

function parse_host_within_brackets(uri_string, pieces) {
  return parse_host_within_brackets_loop(uri_string, uri_string, pieces, 0);
}

function parse_host(uri_string, pieces) {
  let $ = uri_string.charCodeAt(0);
  if ($ === 91) {
    return parse_host_within_brackets(uri_string, pieces);
  } else if ($ === 58) {
    let pieces$1 = new Uri(
      pieces.scheme,
      pieces.userinfo,
      new Some(""),
      pieces.port,
      pieces.path,
      pieces.query,
      pieces.fragment,
    );
    return parse_port(uri_string, pieces$1);
  } else if (uri_string === "") {
    return new Ok(
      new Uri(
        pieces.scheme,
        pieces.userinfo,
        new Some(""),
        pieces.port,
        pieces.path,
        pieces.query,
        pieces.fragment,
      ),
    );
  } else {
    return parse_host_outside_of_brackets(uri_string, pieces);
  }
}

function parse_userinfo_loop(
  loop$original,
  loop$uri_string,
  loop$pieces,
  loop$size
) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size = loop$size;
    let $ = uri_string.charCodeAt(0);
    if ($ === 64) {
      if (size === 0) {
        let rest = uri_string.slice(1);
        return parse_host(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let userinfo = codeunit_slice(original, 0, size);
        let pieces$1 = new Uri(
          pieces.scheme,
          new Some(userinfo),
          pieces.host,
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment,
        );
        return parse_host(rest, pieces$1);
      }
    } else if (uri_string === "") {
      return parse_host(original, pieces);
    } else if ($ === 47) {
      return parse_host(original, pieces);
    } else if ($ === 63) {
      return parse_host(original, pieces);
    } else if ($ === 35) {
      return parse_host(original, pieces);
    } else {
      let $1 = pop_codeunit(uri_string);
      let rest;
      rest = $1[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size + 1;
    }
  }
}

function parse_authority_pieces(string, pieces) {
  return parse_userinfo_loop(string, string, pieces, 0);
}

function parse_authority_with_slashes(uri_string, pieces) {
  if (uri_string === "//") {
    return new Ok(
      new Uri(
        pieces.scheme,
        pieces.userinfo,
        new Some(""),
        pieces.port,
        pieces.path,
        pieces.query,
        pieces.fragment,
      ),
    );
  } else if (uri_string.startsWith("//")) {
    let rest = uri_string.slice(2);
    return parse_authority_pieces(rest, pieces);
  } else {
    return parse_path(uri_string, pieces);
  }
}

function parse_scheme_loop(
  loop$original,
  loop$uri_string,
  loop$pieces,
  loop$size
) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size = loop$size;
    let $ = uri_string.charCodeAt(0);
    if ($ === 47) {
      if (size === 0) {
        return parse_authority_with_slashes(uri_string, pieces);
      } else {
        let scheme = codeunit_slice(original, 0, size);
        let pieces$1 = new Uri(
          new Some($string.lowercase(scheme)),
          pieces.userinfo,
          pieces.host,
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment,
        );
        return parse_authority_with_slashes(uri_string, pieces$1);
      }
    } else if ($ === 63) {
      if (size === 0) {
        let rest = uri_string.slice(1);
        return parse_query_with_question_mark(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let scheme = codeunit_slice(original, 0, size);
        let pieces$1 = new Uri(
          new Some($string.lowercase(scheme)),
          pieces.userinfo,
          pieces.host,
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment,
        );
        return parse_query_with_question_mark(rest, pieces$1);
      }
    } else if ($ === 35) {
      if (size === 0) {
        let rest = uri_string.slice(1);
        return parse_fragment(rest, pieces);
      } else {
        let rest = uri_string.slice(1);
        let scheme = codeunit_slice(original, 0, size);
        let pieces$1 = new Uri(
          new Some($string.lowercase(scheme)),
          pieces.userinfo,
          pieces.host,
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment,
        );
        return parse_fragment(rest, pieces$1);
      }
    } else if ($ === 58) {
      if (size === 0) {
        return new Error(undefined);
      } else {
        let rest = uri_string.slice(1);
        let scheme = codeunit_slice(original, 0, size);
        let pieces$1 = new Uri(
          new Some($string.lowercase(scheme)),
          pieces.userinfo,
          pieces.host,
          pieces.port,
          pieces.path,
          pieces.query,
          pieces.fragment,
        );
        return parse_authority_with_slashes(rest, pieces$1);
      }
    } else if (uri_string === "") {
      return new Ok(
        new Uri(
          pieces.scheme,
          pieces.userinfo,
          pieces.host,
          pieces.port,
          original,
          pieces.query,
          pieces.fragment,
        ),
      );
    } else {
      let $1 = pop_codeunit(uri_string);
      let rest;
      rest = $1[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size + 1;
    }
  }
}

/**
 * Parses a compliant URI string into the `Uri` type.
 * If the string is not a valid URI string then an error is returned.
 *
 * The opposite operation is `uri.to_string`.
 *
 * ## Examples
 *
 * ```gleam
 * assert parse("https://example.com:1234/a/b?query=true#fragment")
 *   == Ok(
 *     Uri(
 *       scheme: Some("https"),
 *       userinfo: None,
 *       host: Some("example.com"),
 *       port: Some(1234),
 *       path: "/a/b",
 *       query: Some("query=true"),
 *       fragment: Some("fragment")
 *     )
 *   )
 * ```
 */
export function parse(uri_string) {
  return parse_scheme_loop(uri_string, uri_string, empty, 0);
}

function percent_encode_query(part) {
  let _pipe = percent_encode(part);
  return $string.replace(_pipe, "+", "%2B");
}

function query_pair(pair) {
  let _pipe = toList([
    percent_encode_query(pair[0]),
    "=",
    percent_encode_query(pair[1]),
  ]);
  return $string_tree.from_strings(_pipe);
}

/**
 * Encodes a list of key value pairs as a URI query string.
 *
 * The opposite operation is `uri.parse_query`.
 *
 * ## Examples
 *
 * ```gleam
 * assert query_to_string([#("a", "1"), #("b", "2")]) == "a=1&b=2"
 * ```
 */
export function query_to_string(query) {
  let _pipe = query;
  let _pipe$1 = $list.map(_pipe, query_pair);
  let _pipe$2 = $list.intersperse(_pipe$1, $string_tree.from_string("&"));
  let _pipe$3 = $string_tree.concat(_pipe$2);
  return $string_tree.to_string(_pipe$3);
}

function remove_dot_segments_loop(loop$input, loop$accumulator) {
  while (true) {
    let input = loop$input;
    let accumulator = loop$accumulator;
    if (input instanceof $Empty) {
      return $list.reverse(accumulator);
    } else {
      let segment = input.head;
      let rest = input.tail;
      let _block;
      if (segment === "") {
        _block = accumulator;
      } else if (segment === ".") {
        _block = accumulator;
      } else if (segment === "..") {
        if (accumulator instanceof $Empty) {
          _block = accumulator;
        } else {
          let accumulator$1 = accumulator.tail;
          _block = accumulator$1;
        }
      } else {
        let segment$1 = segment;
        let accumulator$1 = accumulator;
        _block = listPrepend(segment$1, accumulator$1);
      }
      let accumulator$1 = _block;
      loop$input = rest;
      loop$accumulator = accumulator$1;
    }
  }
}

function remove_dot_segments(input) {
  return remove_dot_segments_loop(input, toList([]));
}

/**
 * Splits the path section of a URI into its constituent segments.
 *
 * Removes empty segments and resolves dot-segments as specified in
 * [section 5.2](https://www.ietf.org/rfc/rfc3986.html#section-5.2) of the RFC.
 *
 * ## Examples
 *
 * ```gleam
 * assert path_segments("/users/1") == ["users" ,"1"]
 * ```
 */
export function path_segments(path) {
  return remove_dot_segments($string.split(path, "/"));
}

/**
 * Encodes a `Uri` value as a URI string.
 *
 * The opposite operation is `uri.parse`.
 *
 * ## Examples
 *
 * ```gleam
 * let uri = Uri(..empty, scheme: Some("https"), host: Some("example.com"))
 * assert to_string(uri) == "https://example.com"
 * ```
 */
export function to_string(uri) {
  let _block;
  let $ = uri.fragment;
  if ($ instanceof Some) {
    let fragment = $[0];
    _block = toList(["#", fragment]);
  } else {
    _block = toList([]);
  }
  let parts = _block;
  let _block$1;
  let $1 = uri.query;
  if ($1 instanceof Some) {
    let query = $1[0];
    _block$1 = listPrepend("?", listPrepend(query, parts));
  } else {
    _block$1 = parts;
  }
  let parts$1 = _block$1;
  let parts$2 = listPrepend(uri.path, parts$1);
  let _block$2;
  let $2 = uri.host;
  let $3 = $string.starts_with(uri.path, "/");
  if ($2 instanceof Some && !$3) {
    let host = $2[0];
    if (host !== "") {
      _block$2 = listPrepend("/", parts$2);
    } else {
      _block$2 = parts$2;
    }
  } else {
    _block$2 = parts$2;
  }
  let parts$3 = _block$2;
  let _block$3;
  let $4 = uri.host;
  let $5 = uri.port;
  if ($4 instanceof Some && $5 instanceof Some) {
    let port = $5[0];
    _block$3 = listPrepend(":", listPrepend($int.to_string(port), parts$3));
  } else {
    _block$3 = parts$3;
  }
  let parts$4 = _block$3;
  let _block$4;
  let $6 = uri.scheme;
  let $7 = uri.userinfo;
  let $8 = uri.host;
  if ($6 instanceof Some) {
    if ($7 instanceof Some) {
      if ($8 instanceof Some) {
        let s = $6[0];
        let u = $7[0];
        let h = $8[0];
        _block$4 = listPrepend(
          s,
          listPrepend(
            "://",
            listPrepend(u, listPrepend("@", listPrepend(h, parts$4))),
          ),
        );
      } else {
        let s = $6[0];
        _block$4 = listPrepend(s, listPrepend(":", parts$4));
      }
    } else if ($8 instanceof Some) {
      let s = $6[0];
      let h = $8[0];
      _block$4 = listPrepend(s, listPrepend("://", listPrepend(h, parts$4)));
    } else {
      let s = $6[0];
      _block$4 = listPrepend(s, listPrepend(":", parts$4));
    }
  } else if ($7 instanceof None && $8 instanceof Some) {
    let h = $8[0];
    _block$4 = listPrepend("//", listPrepend(h, parts$4));
  } else {
    _block$4 = parts$4;
  }
  let parts$5 = _block$4;
  return $string.concat(parts$5);
}

/**
 * Fetches the origin of a URI.
 *
 * Returns the origin of a uri as defined in
 * [RFC 6454](https://tools.ietf.org/html/rfc6454)
 *
 * The supported URI schemes are `http` and `https`.
 * URLs without a scheme will return `Error`.
 *
 * ## Examples
 *
 * ```gleam
 * let assert Ok(uri) = parse("https://example.com/path?foo#bar")
 * assert origin(uri) == Ok("https://example.com")
 * ```
 */
export function origin(uri) {
  let scheme;
  let host;
  let port;
  scheme = uri.scheme;
  host = uri.host;
  port = uri.port;
  if (host instanceof Some && scheme instanceof Some) {
    let $ = scheme[0];
    if ($ === "https" && isEqual(port, new Some(443))) {
      let h = host[0];
      return new Ok($string.concat(toList(["https://", h])));
    } else if ($ === "http" && isEqual(port, new Some(80))) {
      let h = host[0];
      return new Ok($string.concat(toList(["http://", h])));
    } else {
      let s = $;
      if ((s === "http") || (s === "https")) {
        let h = host[0];
        if (port instanceof Some) {
          let p = port[0];
          return new Ok(
            $string.concat(toList([s, "://", h, ":", $int.to_string(p)])),
          );
        } else {
          return new Ok($string.concat(toList([s, "://", h])));
        }
      } else {
        return new Error(undefined);
      }
    }
  } else {
    return new Error(undefined);
  }
}

function join_segments(segments) {
  return $string.join(listPrepend("", segments), "/");
}

function drop_last(elements) {
  return $list.take(elements, $list.length(elements) - 1);
}

/**
 * Resolves a URI with respect to the given base URI.
 *
 * The base URI must be an absolute URI or this function will return an error.
 * The algorithm for merging URIs is described in
 * [RFC 3986](https://tools.ietf.org/html/rfc3986#section-5.2).
 */
export function merge(base, relative) {
  let $ = base.scheme;
  if ($ instanceof Some) {
    let $1 = base.host;
    if ($1 instanceof Some) {
      let $2 = relative.host;
      if ($2 instanceof Some) {
        let _block;
        let _pipe = relative.path;
        let _pipe$1 = $string.split(_pipe, "/");
        let _pipe$2 = remove_dot_segments(_pipe$1);
        _block = join_segments(_pipe$2);
        let path = _block;
        let resolved = new Uri(
          $option.or(relative.scheme, base.scheme),
          new None(),
          relative.host,
          $option.or(relative.port, base.port),
          path,
          relative.query,
          relative.fragment,
        );
        return new Ok(resolved);
      } else {
        let _block;
        let $4 = relative.path;
        if ($4 === "") {
          _block = [base.path, $option.or(relative.query, base.query)];
        } else {
          let _block$1;
          let $5 = $string.starts_with(relative.path, "/");
          if ($5) {
            _block$1 = $string.split(relative.path, "/");
          } else {
            let _pipe = base.path;
            let _pipe$1 = $string.split(_pipe, "/");
            let _pipe$2 = drop_last(_pipe$1);
            _block$1 = $list.append(_pipe$2, $string.split(relative.path, "/"));
          }
          let path_segments$1 = _block$1;
          let _block$2;
          let _pipe = path_segments$1;
          let _pipe$1 = remove_dot_segments(_pipe);
          _block$2 = join_segments(_pipe$1);
          let path = _block$2;
          _block = [path, relative.query];
        }
        let $3 = _block;
        let new_path;
        let new_query;
        new_path = $3[0];
        new_query = $3[1];
        let resolved = new Uri(
          base.scheme,
          new None(),
          base.host,
          base.port,
          new_path,
          new_query,
          relative.fragment,
        );
        return new Ok(resolved);
      }
    } else {
      return new Error(undefined);
    }
  } else {
    return new Error(undefined);
  }
}
