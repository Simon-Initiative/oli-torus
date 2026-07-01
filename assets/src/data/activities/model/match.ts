export type NumericOperator =
  | 'equal'
  | 'not_equal'
  | 'greater_than'
  | 'greater_than_or_equal'
  | 'less_than'
  | 'less_than_or_equal'
  | 'between'
  | 'not_between';

export type NumericTolerance =
  | { type: 'none' }
  | { type: 'absolute'; value: number }
  | { type: 'relative'; value: number }
  | { type: 'absolute_or_relative'; absolute: number; relative: number };

export type NumericRepresentation = { type: 'any' | 'integer' | 'decimal' | 'scientific' };

export type NumericPrecision =
  | { type: 'none' }
  | { type: 'significant_figures' | 'legacy_significant_figures'; count: number }
  | { type: 'decimal_places'; rule: 'exactly' | 'at_least' | 'at_most'; count: number };

export type NumericMatchSpec = {
  mode: 'numeric';
  operator: NumericOperator;
  expected?: string;
  threshold?: string;
  lower?: string;
  upper?: string;
  bounds?: 'inclusive' | 'exclusive';
  tolerance?: NumericTolerance;
  representation?: NumericRepresentation;
  precision?: NumericPrecision;
};

export type NumericComparisonSpec = Omit<NumericMatchSpec, 'mode'>;

export type ExactFormConfig =
  | { type: 'none' | 'integer' | 'fraction' | 'simplified_fraction' }
  | {
      type: 'decimal';
      precision?: { type: 'any' } | { type: 'decimal_places'; rule: string; count: number };
    };

export type MathExpressionQuestionType =
  | 'numeric'
  | 'algebraic'
  | 'number_with_units'
  | 'expression_with_units'
  | 'integer'
  | 'decimal'
  | 'fraction'
  | 'simplified_fraction'
  | 'latex_direct';

export type VariableBound = { value: number; inclusive: boolean };

export type VariableDomain = {
  name: string;
  lower: VariableBound;
  upper: VariableBound;
  exclusions?: number[];
  integerOnly?: boolean;
  preferredValues?: number[];
};

export type AlgebraicValidationConfig = {
  allowedVariables?: string[];
  domains?: VariableDomain[];
};

export type NumericQuestionConfig = {
  integerOnly?: boolean;
};

export type MathExpressionQuestionConfig = {
  numeric?: NumericQuestionConfig;
  validation?: AlgebraicValidationConfig;
  unitPolicy?: UnitPolicy;
  sampling?: SamplingConfig;
};

export type SamplingConfig = {
  seed: number;
  desiredCount: number;
  maxAttempts: number;
  includeSpecialPoints: boolean;
};

export type MathExpressionItemConfig = {
  version: 1;
  type: 'math_expression';
  subtype: MathExpressionQuestionType;
  config?: MathExpressionQuestionConfig;
};

export type ItemConfig = MathExpressionItemConfig;

export type AlgebraicEquivalenceSpec = {
  mode: 'algebraic_equivalence';
  expected: string;
  validation?: AlgebraicValidationConfig;
  sampling?: SamplingConfig;
  form?: ExactFormConfig;
  expressionMatch?: 'equivalent' | 'exact';
};

export type LatexDirectSpec = {
  mode: 'latex_direct';
  expected: string;
};

export type UnitPolicy =
  | { type: 'ignored' }
  | { type: 'accepted_units' | 'convertible_units'; units: string[] }
  | { type: 'strict_unit'; unit: string };

export type UnitAwareSpec = {
  mode: 'unit_aware';
  expected: string;
  unitPolicy?: UnitPolicy;
  validation?: AlgebraicValidationConfig;
  sampling?: SamplingConfig;
  operator?: NumericOperator;
  threshold?: string;
  lower?: string;
  upper?: string;
  bounds?: 'inclusive' | 'exclusive';
  tolerance?: NumericTolerance;
  representation?: NumericRepresentation;
  precision?: NumericPrecision;
  matchWrongUnits?: boolean;
  matchMissingUnit?: boolean;
  expressionMatch?: 'equivalent' | 'exact';
};

export type MathExpressionSpec =
  | NumericMatchSpec
  | LatexDirectSpec
  | AlgebraicEquivalenceSpec
  | UnitAwareSpec;

export type AlwaysMatchConfig = {
  version: 1;
  type: 'always';
};

export type MathExpressionMatchConfig = {
  version: 1;
  type: 'math_expression';
  math: MathExpressionSpec;
};

export type MatchConfig = AlwaysMatchConfig | MathExpressionMatchConfig;

export const MatchConfigs = {
  always: (): AlwaysMatchConfig => ({
    version: 1,
    type: 'always',
  }),

  latexDirect: (expected: string): MathExpressionMatchConfig => ({
    version: 1,
    type: 'math_expression',
    math: {
      mode: 'latex_direct',
      expected,
    },
  }),

  algebraicEquivalence: (
    expected: string,
    options: Omit<AlgebraicEquivalenceSpec, 'mode' | 'expected'> = {},
  ): MathExpressionMatchConfig => ({
    version: 1,
    type: 'math_expression',
    math: {
      mode: 'algebraic_equivalence',
      expected,
      ...options,
    },
  }),

  numeric: (spec: Omit<NumericMatchSpec, 'mode'>): MathExpressionMatchConfig => ({
    version: 1,
    type: 'math_expression',
    math: {
      mode: 'numeric',
      ...spec,
    },
  }),

  unitAware: (
    expected: string,
    unitPolicy?: UnitPolicy,
    options: Omit<UnitAwareSpec, 'mode' | 'expected' | 'unitPolicy'> = {},
  ): MathExpressionMatchConfig => ({
    version: 1,
    type: 'math_expression',
    math: {
      mode: 'unit_aware',
      expected,
      ...(unitPolicy ? { unitPolicy } : {}),
      ...options,
    },
  }),
};

export const ItemConfigs = {
  mathExpression: (
    subtype: MathExpressionQuestionType,
    config?: MathExpressionQuestionConfig,
  ): MathExpressionItemConfig => ({
    version: 1,
    type: 'math_expression',
    subtype,
    ...(config ? { config } : {}),
  }),
};

export const isAlwaysMatchConfig = (matchConfig: MatchConfig | undefined): boolean =>
  matchConfig?.type === 'always';
