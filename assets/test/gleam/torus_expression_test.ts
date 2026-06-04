import { previewMathExpressionSyntax } from 'gleam/torusExpression';
import type { MathExpressionSyntaxKind } from 'gleam/torusExpression';
import { parsed_quantity_to_latex, parsed_to_latex } from 'gleam_build/oli/math/latex.mjs';
import { parse } from 'gleam_build/oli/math/parser.mjs';
import { parse_quantity_or_expression } from 'gleam_build/oli/math/units/quantity.mjs';

jest.mock(
  'gleam_build/oli/math/parser.mjs',
  () => ({
    parse: jest.fn(),
  }),
  { virtual: true },
);

jest.mock(
  'gleam_build/oli/math/format.mjs',
  () => ({
    parse_error_to_debug_string: jest.fn((error) => `parse:${error}`),
    to_debug_string: jest.fn((parsed) => `debug:${parsed}`),
  }),
  { virtual: true },
);

jest.mock(
  'gleam_build/oli/math/latex.mjs',
  () => ({
    parsed_quantity_to_latex: jest.fn((parsed) => `quantity-latex:${parsed}`),
    parsed_to_latex: jest.fn((parsed) => `latex:${parsed}`),
  }),
  { virtual: true },
);

jest.mock(
  'gleam_build/oli/math/units/quantity.mjs',
  () => ({
    parse_quantity_or_expression: jest.fn(),
  }),
  { virtual: true },
);

jest.mock(
  'gleam_build/oli/math/units/format.mjs',
  () => ({
    parsed_quantity_to_debug_string: jest.fn((parsed) => `quantity-debug:${parsed}`),
    quantity_parse_error_to_debug_string: jest.fn((error) => `quantity-error:${error}`),
  }),
  { virtual: true },
);

const parser = { parse: parse as jest.Mock };
const quantity = { parse_quantity_or_expression: parse_quantity_or_expression as jest.Mock };
const latex = {
  parsed_to_latex: parsed_to_latex as jest.Mock,
  parsed_quantity_to_latex: parsed_quantity_to_latex as jest.Mock,
};

// @ac "AC-023" Preview output is produced from parser results, not raw ASCII input.
// @ac "AC-031" Parser-facing adapter tests run alongside the full Gleam parser/evaluator suites.
// @ac "AC-032" Adapter failure paths return controlled results without logging raw expressions.
const ok = (value: unknown) => ({
  0: value,
  isOk: () => true,
});

const error = (value: unknown) => ({
  0: value,
  isOk: () => false,
});

describe('torusExpression preview adapter', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns empty without calling generated parser modules', () => {
    expect(previewMathExpressionSyntax('   ', 'expression')).toEqual({ status: 'empty' });
    expect(parser.parse).not.toHaveBeenCalled();
    expect(quantity.parse_quantity_or_expression).not.toHaveBeenCalled();
  });

  it('returns parser-derived LaTeX for valid expression syntax', () => {
    parser.parse.mockReturnValue(ok('parsed-expression'));

    expect(previewMathExpressionSyntax('2x + 6', 'expression')).toEqual({
      status: 'valid',
      debug: 'debug:parsed-expression',
      latex: 'latex:parsed-expression',
    });
    expect(latex.parsed_to_latex).toHaveBeenCalledWith('parsed-expression');
  });

  it('suppresses preview LaTeX for invalid expression syntax', () => {
    parser.parse.mockReturnValue(error('bad-expression'));

    expect(previewMathExpressionSyntax('2^^3', 'expression')).toEqual({
      status: 'invalid',
      debug: 'parse:bad-expression',
    });
    expect(latex.parsed_to_latex).not.toHaveBeenCalled();
  });

  it('returns parser-derived LaTeX for valid quantity syntax', () => {
    quantity.parse_quantity_or_expression.mockReturnValue(ok('parsed-quantity'));

    expect(previewMathExpressionSyntax('9.8 m/s^2', 'quantity')).toEqual({
      status: 'valid',
      debug: 'quantity-debug:parsed-quantity',
      latex: 'quantity-latex:parsed-quantity',
    });
    expect(latex.parsed_quantity_to_latex).toHaveBeenCalledWith('parsed-quantity');
  });

  it('suppresses preview LaTeX for invalid quantity syntax', () => {
    quantity.parse_quantity_or_expression.mockReturnValue(error('bad-quantity'));

    expect(previewMathExpressionSyntax('9.8m/s^2', 'quantity')).toEqual({
      status: 'invalid',
      debug: 'quantity-error:bad-quantity',
    });
    expect(latex.parsed_quantity_to_latex).not.toHaveBeenCalled();
  });

  it('routes by syntax kind', () => {
    const kind: MathExpressionSyntaxKind = 'quantity';
    quantity.parse_quantity_or_expression.mockReturnValue(ok('parsed-quantity'));

    previewMathExpressionSyntax('9.8 m/s^2', kind);

    expect(quantity.parse_quantity_or_expression).toHaveBeenCalledWith('9.8 m/s^2');
    expect(parser.parse).not.toHaveBeenCalled();
  });
});
