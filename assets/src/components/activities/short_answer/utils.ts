import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { InputType, ShortAnswerModelSchema } from 'components/activities/short_answer/schema';
import {
  ItemConfigs,
  MatchConfig,
  MatchConfigs,
  MathExpressionItemConfig,
  MathExpressionQuestionConfig,
  MathExpressionQuestionType,
  NumericRepresentation,
  SamplingConfig,
  VariableDomain,
} from 'data/activities/model/match';
import {
  Responses,
  getCorrectResponse,
  getIncorrectResponse,
  getResponsesByPartId,
} from 'data/activities/model/responses';
import {
  InputKind,
  InputRange,
  InputText,
  containsRule,
  eqRule,
  equalsRule,
  matchRule,
  parseInputFromRule,
} from 'data/activities/model/rules';
import {
  CreationData,
  HasParts,
  Hint,
  Part,
  Response,
  ScoringStrategy,
  makeFeedback,
  makeHint,
  makeResponse,
  makeStem,
} from '../types';

export const defaultModel: () => ShortAnswerModelSchema = () => {
  return {
    stem: makeStem(''),
    inputType: 'text',
    authoring: {
      parts: [
        {
          id: '1',
          scoringStrategy: ScoringStrategy.average,
          responses: Responses.forTextInput(),
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      transformations: [],
      previewText: '',
    },
  };
};

export const sAModel: (creationData: CreationData) => ShortAnswerModelSchema = (
  creationData: CreationData,
) => {
  const hints: Hint[] = Object.entries(creationData)
    .filter(([key, _value]) => key.startsWith('hint'))
    .map(([_key, value]) => {
      if (value) {
        return makeHint(value as string);
      }
      return makeHint('');
    });

  const correctFeedback = creationData.correct_feedback ? creationData.correct_feedback : 'Correct';
  const incorrectFeedback = creationData.incorrect_feedback
    ? creationData.incorrect_feedback
    : 'Incorrect';

  let response = Responses.forTextInput();
  let inputType: InputType = 'text';
  switch (creationData.type.toLowerCase()) {
    case 'number':
      response = [
        makeResponse(eqRule(creationData.answer), 1, correctFeedback, true),
        Responses.catchAll(incorrectFeedback),
      ];
      inputType = 'numeric';
      break;
    case 'text':
      response = [
        makeResponse(containsRule(creationData.answer), 1, correctFeedback, true),
        Responses.catchAll(incorrectFeedback),
      ];
      inputType = 'text';
      break;
    case 'paragraph':
      response = [makeResponse(matchRule('.*'), 0, 'correct', true)];
      inputType = 'textarea';
      break;
    case 'math':
      response = [
        makeResponse(equalsRule(creationData.answer), 1, correctFeedback, true),
        Responses.catchAll(incorrectFeedback),
      ];
      inputType = 'math';
      break;
    case 'math_expression':
    case 'expression':
      response = Responses.forMathExpression(
        creationData.answer,
        correctFeedback,
        incorrectFeedback,
      );
      inputType = 'math_expression';
      break;
    default:
      break;
  }

  const part: Part = {
    id: '1',
    scoringStrategy: ScoringStrategy.average,
    responses: response,
    hints: hints,
  };

  if (creationData.explanation) {
    part.explanation = makeFeedback(creationData.explanation);
  }

  const stem = creationData.stem ? creationData.stem : '';
  const model: ShortAnswerModelSchema = {
    stem: makeStem(stem),
    inputType: inputType,
    authoring: {
      parts: [part],
      transformations: [],
      previewText: '',
    },
  };

  if (inputType === 'math_expression') {
    const questionType = 'algebraic';
    model.itemConfig = mathExpressionItemConfigForQuestionType(
      questionType,
      defaultMathExpressionConfig(questionType),
    );
  }

  return model;
};

export const getTargetedResponses = (model: HasParts, partId: string) =>
  getResponsesByPartId(model, partId).filter(
    (response) =>
      response !== getCorrectResponse(model, partId) &&
      response !== getIncorrectResponse(model, partId),
  );

export type ShortAnswerQuestionType = MathExpressionQuestionType | 'text' | 'textarea';

const exactFormTypes: MathExpressionQuestionType[] = [
  'integer',
  'decimal',
  'fraction',
  'simplified_fraction',
];

const visibleQuestionType = (type: MathExpressionQuestionType): MathExpressionQuestionType =>
  type === 'integer' || type === 'decimal'
    ? 'numeric'
    : type === 'simplified_fraction'
    ? 'fraction'
    : type;

export const isMathExpressionQuestionType = (
  value: ShortAnswerQuestionType,
): value is MathExpressionQuestionType => value !== 'text' && value !== 'textarea';

const defaultVariableDomain = (name = 'x'): VariableDomain => ({
  name,
  lower: { value: -10, inclusive: true },
  upper: { value: 10, inclusive: true },
  exclusions: [],
  integerOnly: false,
  preferredValues: [],
});

export const defaultSamplingConfig = (): SamplingConfig => ({
  seed: 42,
  desiredCount: 8,
  maxAttempts: 64,
  includeSpecialPoints: true,
});

export const defaultMathExpressionConfig = (
  type: MathExpressionQuestionType,
): MathExpressionQuestionConfig => {
  if (type === 'numeric') {
    return {
      numeric: {
        integerOnly: false,
      },
    };
  }

  if (type === 'expression_with_units') {
    return {
      validation: {
        allowedVariables: ['x'],
        domains: [defaultVariableDomain('x')],
      },
      sampling: defaultSamplingConfig(),
      unitPolicy: {
        type: 'convertible_units',
        units: ['m/s'],
      },
    };
  }

  if (type === 'number_with_units') {
    return {
      unitPolicy: {
        type: 'convertible_units',
        units: ['m/s'],
      },
    };
  }

  if (type === 'algebraic') {
    return {
      validation: {
        allowedVariables: ['x'],
        domains: [defaultVariableDomain('x')],
      },
      sampling: defaultSamplingConfig(),
    };
  }

  return {};
};

export const mathExpressionItemConfigForQuestionType = (
  type: MathExpressionQuestionType,
  config: MathExpressionQuestionConfig = {},
): MathExpressionItemConfig => ItemConfigs.mathExpression(visibleQuestionType(type), config);

export const numericRepresentationForConfig = (
  config: MathExpressionQuestionConfig = {},
): NumericRepresentation => ({
  type: config.numeric?.integerOnly === true ? 'integer' : 'any',
});

export const mathExpressionMatchConfigForQuestionType = (
  type: MathExpressionQuestionType,
  expected = '',
  config: MathExpressionQuestionConfig = {},
  options: {
    matchWrongUnits?: boolean;
    matchMissingUnit?: boolean;
    fractionMatch?: 'exact' | 'equivalent';
    expressionMatch?: 'equivalent' | 'exact';
  } = {},
): MatchConfig => {
  switch (type) {
    case 'numeric':
      return MatchConfigs.numeric({
        operator: 'equal',
        expected: expected || '1',
        representation: numericRepresentationForConfig(config),
      });
    case 'latex_direct':
      return MatchConfigs.latexDirect(expected);
    case 'number_with_units':
    case 'expression_with_units':
      return MatchConfigs.unitAware(expected, undefined, {
        ...(options.matchWrongUnits ? { matchWrongUnits: true } : {}),
        ...(options.matchMissingUnit ? { matchMissingUnit: true } : {}),
        ...(type === 'expression_with_units' && config.sampling
          ? { sampling: config.sampling }
          : {}),
        ...(type === 'expression_with_units' && options.expressionMatch === 'exact'
          ? { expressionMatch: 'exact' }
          : {}),
      });
    case 'fraction':
      return MatchConfigs.algebraicEquivalence(expected, {
        form: {
          type: options.fractionMatch === 'equivalent' ? 'fraction' : 'simplified_fraction',
        },
      });
    case 'integer':
    case 'decimal':
    case 'simplified_fraction':
      return MatchConfigs.algebraicEquivalence(expected, {
        form: { type },
      });
    case 'algebraic':
      return MatchConfigs.algebraicEquivalence(expected, {
        ...(config.sampling ? { sampling: config.sampling } : {}),
        ...(options.expressionMatch === 'exact' ? { expressionMatch: 'exact' } : {}),
      });
  }
};

export const applyMathExpressionConfigToMatchConfig = (
  questionType: MathExpressionQuestionType,
  matchConfig: MatchConfig | undefined,
  fallbackExpected: string,
  config: MathExpressionQuestionConfig = {},
  options: { matchWrongUnits?: boolean; matchMissingUnit?: boolean } = {},
): MatchConfig => {
  if (
    questionType === 'numeric' &&
    matchConfig?.type === 'math_expression' &&
    matchConfig.math.mode === 'numeric'
  ) {
    return {
      ...matchConfig,
      math: {
        ...matchConfig.math,
        representation: numericRepresentationForConfig(config),
      },
    };
  }

  const expressionMatch =
    matchConfig?.type === 'math_expression' &&
    (matchConfig.math.mode === 'algebraic_equivalence' || matchConfig.math.mode === 'unit_aware')
      ? matchConfig.math.expressionMatch
      : undefined;

  return mathExpressionMatchConfigForQuestionType(questionType, fallbackExpected, config, {
    ...options,
    expressionMatch,
  });
};

export const expectedAnswerFromResponse = (response: Response): string => {
  if (response.matchConfig?.type === 'math_expression') {
    const math = response.matchConfig.math;
    if ('expected' in math) return math.expected ?? '';
    if ('threshold' in math) return math.threshold ?? '';
    if ('lower' in math) return math.lower ?? '';
  }

  return parseInputFromRule(response.rule ?? '').caseOf({
    just: (input) => {
      if (input.kind === InputKind.Numeric) return String(input.value);
      if (input.kind === InputKind.Range) return String((input as InputRange).lowerBound);
      return (input as InputText).value;
    },
    nothing: () => '',
  });
};

export const mathExpressionQuestionTypeFromMatchConfig = (
  matchConfig?: MatchConfig,
): MathExpressionQuestionType => {
  if (matchConfig?.type !== 'math_expression') return 'algebraic';

  switch (matchConfig.math.mode) {
    case 'numeric':
      return 'numeric';
    case 'latex_direct':
      return 'latex_direct';
    case 'unit_aware':
      return 'expression_with_units';
    case 'algebraic_equivalence': {
      const formType = matchConfig.math.form?.type;
      if (formType === 'integer' || formType === 'decimal') return 'numeric';
      if (formType === 'simplified_fraction') return 'fraction';

      return exactFormTypes.includes(formType as MathExpressionQuestionType)
        ? (formType as MathExpressionQuestionType)
        : 'algebraic';
    }
  }
};

export const shortAnswerQuestionType = (model: ShortAnswerModelSchema): ShortAnswerQuestionType => {
  if (model.inputType === 'text' || model.inputType === 'textarea') return model.inputType;
  if (model.inputType === 'numeric') return 'numeric';
  if (model.inputType === 'math') return 'latex_direct';

  return visibleQuestionType(
    model.itemConfig?.subtype ??
      mathExpressionQuestionTypeFromMatchConfig(
        getCorrectResponse(model, model.authoring.parts[0].id).matchConfig,
      ),
  );
};

export const mathExpressionConfigFromMatchConfig = (
  matchConfig?: MatchConfig,
): MathExpressionQuestionConfig | undefined => {
  if (matchConfig?.type !== 'math_expression') return undefined;

  switch (matchConfig.math.mode) {
    case 'numeric':
      return {
        numeric: {
          integerOnly: matchConfig.math.representation?.type === 'integer',
        },
      };
    case 'algebraic_equivalence':
      if (matchConfig.math.form?.type === 'integer') {
        return {
          numeric: {
            integerOnly: true,
          },
        };
      }

      if (matchConfig.math.form?.type === 'decimal') {
        return {
          numeric: {
            integerOnly: false,
          },
        };
      }

      return { validation: matchConfig.math.validation, sampling: matchConfig.math.sampling };
    case 'unit_aware':
      return {
        validation: matchConfig.math.validation,
        sampling: matchConfig.math.sampling,
        unitPolicy: matchConfig.math.unitPolicy,
      };
    case 'latex_direct':
      return {};
  }
};

export const shortAnswerMathExpressionConfig = (
  model: ShortAnswerModelSchema,
): MathExpressionQuestionConfig | undefined => {
  if (model.itemConfig?.config) {
    if (model.itemConfig.subtype === 'integer' || model.itemConfig.subtype === 'decimal') {
      return {
        ...model.itemConfig.config,
        numeric: {
          ...(model.itemConfig.config.numeric ?? {}),
          integerOnly: model.itemConfig.subtype === 'integer',
        },
      };
    }

    return model.itemConfig.config;
  }

  return mathExpressionConfigFromMatchConfig(
    getCorrectResponse(model, model.authoring.parts[0].id).matchConfig,
  );
};

export const shortAnswerInputTypeFromQuestionType = (
  questionType: ShortAnswerQuestionType,
): InputType =>
  questionType === 'text' || questionType === 'textarea' ? questionType : 'math_expression';

export type ShortAnswerOption = SelectOption<ShortAnswerQuestionType> & {
  description: string;
  example: string;
};

export type ShortAnswerOptionGroup = {
  label: 'Text' | 'Math/Numeric';
  options: ShortAnswerOption[];
};

export const shortAnswerOptionGroups: ShortAnswerOptionGroup[] = [
  {
    label: 'Text',
    options: [
      {
        value: 'textarea',
        displayValue: 'Paragraph',
        description: 'Longer written response for sentence or paragraph answers.',
        example: 'The graph increases over time.',
      },
      {
        value: 'text',
        displayValue: 'Short Text',
        description: 'Brief text response matched against authored text rules.',
        example: 'photosynthesis',
      },
    ],
  },
  {
    label: 'Math/Numeric',
    options: [
      {
        value: 'algebraic',
        displayValue: 'Algebraic expression',
        description: 'Equivalent algebraic forms are accepted.',
        example: '2(x + 3)',
      },
      {
        value: 'expression_with_units',
        displayValue: 'Algebraic expression with units',
        description: 'A variable expression with required or convertible units.',
        example: 'm*a N',
      },
      {
        value: 'fraction',
        displayValue: 'Fraction',
        description: 'A fraction answer with configurable exact or equivalent matching.',
        example: '1/2',
      },
      {
        value: 'latex_direct',
        displayValue: 'LaTeX Math expression',
        description: 'A LaTeX-style math answer matched directly.',
        example: '\\frac{1}{2}',
      },
      {
        value: 'numeric',
        displayValue: 'Number',
        description: 'A numeric answer compared by value, optionally integer-only.',
        example: '3.14',
      },
      {
        value: 'number_with_units',
        displayValue: 'Number with units',
        description: 'A numeric answer with required or convertible units.',
        example: '10 m/s',
      },
    ],
  },
];

export const shortAnswerOptions: SelectOption<ShortAnswerQuestionType>[] =
  shortAnswerOptionGroups.flatMap(({ options }) =>
    options.map(({ value, displayValue }) => ({ value, displayValue })),
  );

// disable changing of the value via scroll wheel in certain browsers
export const disableScrollWheelChange = (numericInput: React.RefObject<HTMLInputElement>) => () =>
  numericInput.current?.blur();
