import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { ShortAnswerModelSchema } from 'components/activities/short_answer/schema';
import { Response } from 'components/activities/types';
import {
  ItemConfigs,
  MatchConfig,
  MatchConfigs,
  NumericComparisonSpec,
  NumericMatchSpec,
  NumericOperator,
  NumericRepresentation,
  NumericTolerance,
  UnitPolicy,
} from 'data/activities/model/match';
import {
  Input,
  InputKind,
  InputNumeric,
  InputRange,
  InputText,
  isCatchAllResponse,
  parseInputFromRule,
} from 'data/activities/model/rules';

type LegacyMathInputType = 'numeric' | 'math';

const numericOperatorMap: Record<InputNumeric['operator'], NumericOperator> = {
  eq: 'equal',
  neq: 'not_equal',
  gt: 'greater_than',
  gte: 'greater_than_or_equal',
  lt: 'less_than',
  lte: 'less_than_or_equal',
};

const rangeOperatorMap: Record<InputRange['operator'], NumericOperator> = {
  btw: 'between',
  nbtw: 'not_between',
};

const numberPattern = String.raw`[+-]?(?:(?:\d+(?:\.\d*)?)|(?:\.\d+))(?:[eE][+-]?\d+)?`;
const scalarPattern = new RegExp(String.raw`\{(${numberPattern})(?:#(\d+))?\}`);
const rangePattern = new RegExp(
  String.raw`\{([[(])\s*(${numberPattern})\s*,\s*(${numberPattern})\s*([\])])(?:#(\d+))?\}`,
);
const deprecatedInclusiveRangePattern = new RegExp(
  String.raw`= \{(${numberPattern})\}.*= \{(${numberPattern})\}`,
);

const maybePrecision = (count: number | undefined): NumericMatchSpec['precision'] =>
  count === undefined ? undefined : { type: 'significant_figures', count };

const parsePrecision = (raw: string | undefined) => {
  if (!raw) return undefined;

  const count = parseInt(raw, 10);
  return count > 0 ? count : undefined;
};

const scalarParts = (rule: string) => {
  const match = rule.match(scalarPattern);
  if (!match) return undefined;

  return { value: match[1], precision: parsePrecision(match[2]) };
};

const rangeParts = (rule: string) => {
  const rangeMatch = rule.match(rangePattern);
  if (rangeMatch) {
    return {
      lower: rangeMatch[2],
      upper: rangeMatch[3],
      bounds: rangeMatch[1] === '[' && rangeMatch[4] === ']' ? 'inclusive' : 'exclusive',
      precision: parsePrecision(rangeMatch[5]),
    } as const;
  }

  const deprecatedMatch = rule.match(deprecatedInclusiveRangePattern);
  if (!deprecatedMatch) return undefined;

  return {
    lower: deprecatedMatch[1],
    upper: deprecatedMatch[2],
    bounds: 'inclusive',
    precision: undefined,
  } as const;
};

export const numericInputToMatchConfig = (
  input: InputNumeric | InputRange,
  rawRule?: string,
  options: {
    representation?: NumericRepresentation;
    tolerance?: NumericTolerance;
  } = {},
): MatchConfig => {
  if (input.kind === InputKind.Numeric) {
    const scalar = rawRule ? scalarParts(rawRule) : undefined;
    const value = scalar?.value ?? String(input.value);
    const precision = scalar?.precision ?? input.precision;
    const operator = numericOperatorMap[input.operator];
    const valueField = operator === 'equal' || operator === 'not_equal' ? 'expected' : 'threshold';

    return MatchConfigs.numeric({
      operator,
      [valueField]: value,
      precision: maybePrecision(precision),
      ...(options.representation ? { representation: options.representation } : {}),
      ...(options.tolerance ? { tolerance: options.tolerance } : {}),
    });
  }

  const range = rawRule ? rangeParts(rawRule) : undefined;
  const precision = range?.precision ?? input.precision;

  return MatchConfigs.numeric({
    operator: rangeOperatorMap[input.operator],
    lower: range?.lower ?? String(input.lowerBound),
    upper: range?.upper ?? String(input.upperBound),
    bounds: range?.bounds ?? (input.inclusive ? 'inclusive' : 'exclusive'),
    precision: maybePrecision(precision),
    ...(options.representation ? { representation: options.representation } : {}),
    ...(options.tolerance ? { tolerance: options.tolerance } : {}),
  });
};

export const numericInputToUnitAwareMatchConfig = (
  input: InputNumeric | InputRange,
  rawRule?: string,
  options: {
    unitPolicy?: UnitPolicy;
    representation?: NumericRepresentation;
    tolerance?: NumericTolerance;
    matchWrongUnits?: boolean;
    matchMissingUnit?: boolean;
  } = {},
): MatchConfig => {
  const numericMatchConfig = numericInputToMatchConfig(input, rawRule, {
    representation: options.representation,
    tolerance: options.tolerance,
  }) as { math: NumericMatchSpec };
  const { mode: _mode, ...numericSpec } = numericMatchConfig.math as NumericMatchSpec;
  const { expected, ...numericOptions } = numericSpec;

  return MatchConfigs.unitAware(
    expected ?? numericExpectedFromSpec(numericSpec),
    options.unitPolicy,
    {
      ...numericOptions,
      ...(options.matchWrongUnits ? { matchWrongUnits: true } : {}),
      ...(options.matchMissingUnit ? { matchMissingUnit: true } : {}),
    },
  );
};

export const numericInputFromMatchConfig = (
  matchConfig: MatchConfig | undefined,
): InputNumeric | InputRange | undefined => {
  if (
    matchConfig?.type !== 'math_expression' ||
    (matchConfig.math.mode !== 'numeric' && matchConfig.math.mode !== 'unit_aware')
  ) {
    return undefined;
  }

  const math = matchConfig.math;
  if (math.mode === 'unit_aware' && math.operator === undefined && math.expected.trim() === '') {
    return undefined;
  }

  const matchOperator = math.mode === 'unit_aware' ? math.operator ?? 'equal' : math.operator;
  const precision =
    math.precision?.type === 'significant_figures' ||
    math.precision?.type === 'legacy_significant_figures'
      ? math.precision.count
      : undefined;

  switch (matchOperator) {
    case 'equal':
    case 'not_equal':
      return {
        kind: InputKind.Numeric,
        operator: matchOperator === 'equal' ? 'eq' : 'neq',
        value: numericExpectedValue(math.expected),
        precision,
      };
    case 'greater_than':
    case 'greater_than_or_equal':
    case 'less_than':
    case 'less_than_or_equal': {
      const operator = {
        greater_than: 'gt',
        greater_than_or_equal: 'gte',
        less_than: 'lt',
        less_than_or_equal: 'lte',
      }[matchOperator] as InputNumeric['operator'];

      return {
        kind: InputKind.Numeric,
        operator,
        value: math.threshold ?? numericExpectedValue(math.expected),
        precision,
      };
    }
    case 'between':
    case 'not_between':
      return {
        kind: InputKind.Range,
        operator: matchOperator === 'between' ? 'btw' : 'nbtw',
        lowerBound: math.lower ?? numericExpectedValue(math.expected),
        upperBound: math.upper ?? numericExpectedValue(math.expected),
        inclusive: math.bounds !== 'exclusive',
        precision,
      };
  }
};

const numericExpectedFromSpec = (spec: NumericComparisonSpec): string => {
  if (spec.expected !== undefined) return spec.expected;
  if (spec.threshold !== undefined) return spec.threshold;
  if (spec.lower !== undefined) return spec.lower;
  return '';
};

const numericExpectedValue = (expected: string | undefined): string => {
  const value = expected ?? '';
  const match = value.trim().match(new RegExp(`^(${numberPattern})(?=\\s|[A-Za-z*/^]|$)`));

  return match?.[1] ?? value;
};

const responseWithMatchConfig = (response: Response, matchConfig: MatchConfig): Response => {
  return {
    ...response,
    rule: '',
    matchConfig,
  };
};

export const legacyNumericRuleToMatchConfig = (rule: string): MatchConfig | undefined =>
  parseInputFromRule(rule).caseOf({
    just: (input: Input) =>
      input.kind === InputKind.Numeric || input.kind === InputKind.Range
        ? numericInputToMatchConfig(input, rule)
        : undefined,
    nothing: () => undefined,
  });

export const legacyMathRuleToMatchConfig = (rule: string): MatchConfig | undefined =>
  parseInputFromRule(rule).caseOf({
    just: (input: Input) =>
      input.kind === InputKind.Text && (input as InputText).operator === 'equals'
        ? MatchConfigs.latexDirect((input as InputText).value)
        : undefined,
    nothing: () => undefined,
  });

const legacyResponseToMatchConfig = (
  response: Response,
  inputType: LegacyMathInputType,
): Response | undefined => {
  if (response.matchConfig) {
    return responseWithMatchConfig(response, response.matchConfig);
  }

  if (isCatchAllResponse(response)) {
    return responseWithMatchConfig(response, MatchConfigs.always());
  }

  const matchConfig =
    inputType === 'numeric'
      ? legacyNumericRuleToMatchConfig(response.rule)
      : legacyMathRuleToMatchConfig(response.rule);

  return matchConfig ? responseWithMatchConfig(response, matchConfig) : undefined;
};

const convertResponses = (responses: Response[], inputType: LegacyMathInputType) => {
  const converted = responses.map((response) => legacyResponseToMatchConfig(response, inputType));

  return converted.every((response): response is Response => response !== undefined)
    ? converted
    : undefined;
};

export const convertShortAnswerLegacyMathOnSave = (
  model: ShortAnswerModelSchema,
): ShortAnswerModelSchema => {
  if (model.inputType !== 'numeric' && model.inputType !== 'math') return model;

  const convertedResponses = convertResponses(model.authoring.parts[0].responses, model.inputType);
  if (!convertedResponses) return model;

  return {
    ...model,
    inputType: 'math_expression',
    itemConfig: ItemConfigs.mathExpression(
      model.inputType === 'numeric' ? 'numeric' : 'latex_direct',
      {},
    ),
    authoring: {
      ...model.authoring,
      parts: model.authoring.parts.map((part, index) =>
        index === 0 ? { ...part, responses: convertedResponses } : part,
      ),
    },
  };
};

export const convertMultiInputLegacyMathOnSave = (model: MultiInputSchema): MultiInputSchema => {
  const convertedByPartId = new Map<string, Response[]>();
  const convertedInputs = model.inputs.map((input) => {
    if (input.inputType !== 'numeric' && input.inputType !== 'math') return input;

    const part = model.authoring.parts.find((part) => part.id === input.partId);
    if (!part) return input;

    const convertedResponses = convertResponses(part.responses, input.inputType);
    if (!convertedResponses) return input;

    convertedByPartId.set(part.id, convertedResponses);
    return {
      ...input,
      inputType: 'math_expression' as const,
      itemConfig: ItemConfigs.mathExpression(
        input.inputType === 'numeric' ? 'numeric' : 'latex_direct',
        {},
      ),
    };
  });

  if (convertedByPartId.size === 0) return model;

  return {
    ...model,
    inputs: convertedInputs,
    authoring: {
      ...model.authoring,
      parts: model.authoring.parts.map((part) =>
        convertedByPartId.has(part.id)
          ? { ...part, responses: convertedByPartId.get(part.id) as Response[] }
          : part,
      ),
    },
  };
};
