import {
  parse,
  parse_error_to_debug_string,
  to_debug_string,
} from 'gleam_build/oli/torus_math.mjs';

export type GleamParseResult =
  | { status: 'ok'; value: string; inspect: string }
  | { status: 'error'; value: string; inspect: string }
  | { status: 'unknown'; value: string; inspect: string };

export function gleamParse(expression: string): GleamParseResult {
  const result = parse(expression);

  if (result && typeof result.isOk === 'function' && result.isOk()) {
    const debug = to_debug_string(result[0]);
    return {
      status: 'ok',
      value: debug,
      inspect: debug,
    };
  }

  if (result && typeof result.isError === 'function' && result.isError()) {
    const debug = parse_error_to_debug_string(result[0]);
    return {
      status: 'error',
      value: debug,
      inspect: debug,
    };
  }

  return {
    status: 'unknown',
    value: JSON.stringify(result),
    inspect: String(result),
  };
}
