import { parse_error_to_debug_string, to_debug_string } from 'gleam_build/oli/math/format.mjs';
import { parsed_quantity_to_latex, parsed_to_latex } from 'gleam_build/oli/math/latex.mjs';
import { parse } from 'gleam_build/oli/math/parser.mjs';
import {
  parsed_quantity_to_debug_string,
  quantity_parse_error_to_debug_string,
} from 'gleam_build/oli/math/units/format.mjs';
import { parse_quantity_or_expression } from 'gleam_build/oli/math/units/quantity.mjs';

// Keep the browser prototype parser bundle parse-only. Importing the full
// torus_math JS module also pulls in hash support, which depends on Node crypto.
export type GleamParseResult =
  | { status: 'ok'; value: string; inspect: string }
  | { status: 'error'; value: string; inspect: string }
  | { status: 'unknown'; value: string; inspect: string };

export function gleamParse(expression: string): GleamParseResult {
  const result = parse(expression);

  if (isOk(result)) {
    const debug = to_debug_string(result[0]);
    return {
      status: 'ok',
      value: debug,
      inspect: debug,
    };
  }

  if (isError(result)) {
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

export type MathExpressionSyntaxKind = 'expression' | 'quantity';

export type MathExpressionSyntaxResult =
  | { status: 'valid'; debug: string }
  | { status: 'invalid'; debug: string }
  | { status: 'unknown'; debug: string };

export type MathExpressionPreviewResult =
  | { status: 'empty' }
  | { status: 'valid'; debug: string; latex: string }
  | { status: 'invalid'; debug: string }
  | { status: 'unknown'; debug: string };

export function validateMathExpressionSyntax(
  expression: string,
  kind: MathExpressionSyntaxKind,
): MathExpressionSyntaxResult {
  const result = kind === 'quantity' ? parse_quantity_or_expression(expression) : parse(expression);

  if (isOk(result)) {
    const debug = kind === 'quantity' ? 'valid quantity expression' : to_debug_string(result[0]);
    return { status: 'valid', debug };
  }

  if (isError(result)) {
    const debug =
      kind === 'quantity'
        ? quantity_parse_error_to_debug_string(result[0])
        : parse_error_to_debug_string(result[0]);
    return { status: 'invalid', debug };
  }

  return { status: 'unknown', debug: String(result) };
}

export function previewMathExpressionSyntax(
  expression: string,
  kind: MathExpressionSyntaxKind,
): MathExpressionPreviewResult {
  const trimmed = expression.trim();
  if (trimmed === '') {
    return { status: 'empty' };
  }

  return kind === 'quantity' ? previewQuantityExpression(trimmed) : previewPlainExpression(trimmed);
}

function previewPlainExpression(expression: string): MathExpressionPreviewResult {
  const result = parse(expression);

  if (isOk(result)) {
    const parsed = result[0];
    // Preview LaTeX is generated from Torus parser output, not raw ASCII, so
    // MathJax cannot become a second syntax accepted only by the browser.
    return {
      status: 'valid',
      debug: to_debug_string(parsed),
      latex: parsed_to_latex(parsed),
    };
  }

  if (isError(result)) {
    return { status: 'invalid', debug: parse_error_to_debug_string(result[0]) };
  }

  return { status: 'unknown', debug: String(result) };
}

function previewQuantityExpression(expression: string): MathExpressionPreviewResult {
  const result = parse_quantity_or_expression(expression);

  if (isOk(result)) {
    const parsed = result[0];
    return {
      status: 'valid',
      debug: parsed_quantity_to_debug_string(parsed),
      latex: parsed_quantity_to_latex(parsed),
    };
  }

  if (isError(result)) {
    return { status: 'invalid', debug: quantity_parse_error_to_debug_string(result[0]) };
  }

  return { status: 'unknown', debug: String(result) };
}

function isOk(result: unknown): result is { 0: any; isOk: () => true } {
  return (
    typeof result === 'object' &&
    result !== null &&
    typeof (result as { isOk?: unknown }).isOk === 'function' &&
    (result as { isOk: () => boolean }).isOk()
  );
}

function isError(result: unknown): result is { 0: any; isOk: () => false } {
  return (
    typeof result === 'object' &&
    result !== null &&
    typeof (result as { isOk?: unknown }).isOk === 'function' &&
    !(result as { isOk: () => boolean }).isOk()
  );
}
