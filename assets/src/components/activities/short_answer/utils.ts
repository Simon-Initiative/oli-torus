import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { InputType, ShortAnswerModelSchema } from 'components/activities/short_answer/schema';
import {
  ItemConfigs,
  MatchConfig,
  MatchConfigs,
  MathExpressionItemConfig,
  MathExpressionQuestionConfig,
  MathExpressionQuestionType,
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

export const isMathExpressionQuestionType = (
  value: ShortAnswerQuestionType,
): value is MathExpressionQuestionType => value !== 'text' && value !== 'textarea';

export const defaultMathExpressionConfig = (
  type: MathExpressionQuestionType,
): MathExpressionQuestionConfig => {
  if (type === 'expression_with_units') {
    return {
      validation: {
        allowedVariables: [],
        domains: [],
      },
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
        allowedVariables: [],
        domains: [],
      },
    };
  }

  return {};
};

export const mathExpressionItemConfigForQuestionType = (
  type: MathExpressionQuestionType,
  config: MathExpressionQuestionConfig = {},
): MathExpressionItemConfig => ItemConfigs.mathExpression(type, config);

export const mathExpressionMatchConfigForQuestionType = (
  type: MathExpressionQuestionType,
  expected = '',
  config: MathExpressionQuestionConfig = {},
  options: { matchWrongUnits?: boolean } = {},
): MatchConfig => {
  switch (type) {
    case 'numeric':
      return MatchConfigs.numeric({
        operator: 'equal',
        expected: expected || '1',
      });
    case 'latex_direct':
      return MatchConfigs.latexDirect(expected);
    case 'number_with_units':
    case 'expression_with_units':
      return MatchConfigs.unitAware(
        expected,
        undefined,
        options.matchWrongUnits ? { matchWrongUnits: true } : {},
      );
    case 'integer':
    case 'decimal':
    case 'fraction':
    case 'simplified_fraction':
      return MatchConfigs.algebraicEquivalence(expected, {
        form: { type },
      });
    case 'algebraic':
      return MatchConfigs.algebraicEquivalence(expected);
  }
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

  return (
    model.itemConfig?.subtype ??
    mathExpressionQuestionTypeFromMatchConfig(
      getCorrectResponse(model, model.authoring.parts[0].id).matchConfig,
    )
  );
};

export const mathExpressionConfigFromMatchConfig = (
  matchConfig?: MatchConfig,
): MathExpressionQuestionConfig | undefined => {
  if (matchConfig?.type !== 'math_expression') return undefined;

  switch (matchConfig.math.mode) {
    case 'algebraic_equivalence':
      return { validation: matchConfig.math.validation };
    case 'unit_aware':
      return {
        validation: matchConfig.math.validation,
        unitPolicy: matchConfig.math.unitPolicy,
      };
    case 'numeric':
    case 'latex_direct':
      return {};
  }
};

export const shortAnswerMathExpressionConfig = (
  model: ShortAnswerModelSchema,
): MathExpressionQuestionConfig | undefined => {
  if (model.itemConfig?.config) return model.itemConfig.config;

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
        value: 'decimal',
        displayValue: 'Decimal',
        description: 'A decimal-form answer is required.',
        example: '0.5',
      },
      {
        value: 'expression_with_units',
        displayValue: 'Expression with units',
        description: 'A variable expression with required or convertible units.',
        example: 'm*a N',
      },
      {
        value: 'fraction',
        displayValue: 'Fraction',
        description: 'A fraction-form answer is required.',
        example: '2/4',
      },
      {
        value: 'integer',
        displayValue: 'Integer',
        description: 'A whole-number answer is required.',
        example: '42',
      },
      {
        value: 'latex_direct',
        displayValue: 'LaTeX Math expression',
        description: 'A LaTeX-style math answer matched directly.',
        example: '\\frac{1}{2}',
      },
      {
        value: 'number_with_units',
        displayValue: 'Number with units',
        description: 'A numeric answer with required or convertible units.',
        example: '10 m/s',
      },
      {
        value: 'numeric',
        displayValue: 'Numeric',
        description: 'A numeric answer compared by value.',
        example: '3.14',
      },
      {
        value: 'simplified_fraction',
        displayValue: 'Simplified fraction',
        description: 'A reduced fraction-form answer is required.',
        example: '1/2',
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
