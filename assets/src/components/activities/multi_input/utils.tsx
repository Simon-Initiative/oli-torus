import React from 'react';
import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { setDifference, setUnion } from 'components/activities/common/utils';
import { MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import {
  ShortAnswerQuestionType,
  defaultMathExpressionConfig,
  mathExpressionConfigFromMatchConfig,
  mathExpressionQuestionTypeFromMatchConfig,
} from 'components/activities/short_answer/utils';
import {
  Part,
  Transform,
  makeChoice,
  makeHint,
  makePart,
  makeTransformation,
} from 'components/activities/types';
import { MatchConfig, MathExpressionQuestionConfig } from 'data/activities/model/match';
import { Responses } from 'data/activities/model/responses';
import { isTextRule } from 'data/activities/model/rules';
import { Model } from 'data/content/model/elements/factories';
import { InputRef, Paragraph } from 'data/content/model/elements/types';
import { elementsOfType } from 'data/content/utils';
import { clone } from 'utils/common';
import { isDefined } from 'utils/common';
import guid from 'utils/guid';

export const multiInputOptions: SelectOption<'text' | 'numeric'>[] = [
  { value: 'numeric', displayValue: 'Number' },
  { value: 'text', displayValue: 'Text' },
];

export type MultiInputQuestionType = 'dropdown' | Exclude<ShortAnswerQuestionType, 'textarea'>;

const visibleQuestionType = (
  type: Exclude<ShortAnswerQuestionType, 'textarea'>,
): Exclude<ShortAnswerQuestionType, 'textarea'> =>
  type === 'integer' || type === 'decimal'
    ? 'numeric'
    : type === 'simplified_fraction'
    ? 'fraction'
    : type;

export type MultiInputQuestionOption = SelectOption<MultiInputQuestionType> & {
  description: string;
  example: string;
};

export type MultiInputQuestionOptionGroup = {
  label: 'Text' | 'Math/Numeric';
  options: MultiInputQuestionOption[];
};

export const multiInputQuestionOptionGroups: MultiInputQuestionOptionGroup[] = [
  {
    label: 'Text',
    options: [
      {
        value: 'dropdown',
        displayValue: 'Dropdown',
        description: 'A selectable list of authored choices.',
        example: 'Choice A',
      },
      {
        value: 'text',
        displayValue: 'Text',
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

export const multiInputQuestionOptions: SelectOption<MultiInputQuestionType>[] =
  multiInputQuestionOptionGroups.flatMap(({ options }) =>
    options.map(({ value, displayValue }) => ({ value, displayValue })),
  );

export const isMultiInputMathExpressionQuestionType = (
  value: MultiInputQuestionType,
): value is Exclude<MultiInputQuestionType, 'dropdown' | 'text'> =>
  value !== 'dropdown' && value !== 'text';

export const multiInputQuestionType = (
  input: MultiInput,
  matchConfig?: MatchConfig,
): MultiInputQuestionType => {
  if (input.inputType === 'dropdown' || input.inputType === 'text') return input.inputType;
  if (input.inputType === 'numeric') return 'numeric';
  if (input.inputType === 'math') return 'latex_direct';

  return visibleQuestionType(
    input.itemConfig?.subtype ?? mathExpressionQuestionTypeFromMatchConfig(matchConfig),
  );
};

export const multiInputMathExpressionConfig = (
  input: MultiInput,
  matchConfig?: MatchConfig,
): MathExpressionQuestionConfig | undefined => {
  if (input.inputType !== 'math_expression') return undefined;

  if (
    input.itemConfig?.config &&
    (input.itemConfig.subtype === 'integer' || input.itemConfig.subtype === 'decimal')
  ) {
    return {
      ...input.itemConfig.config,
      numeric: {
        ...(input.itemConfig.config.numeric ?? {}),
        integerOnly: input.itemConfig.subtype === 'integer',
      },
    };
  }

  return input.itemConfig?.config ?? mathExpressionConfigFromMatchConfig(matchConfig);
};

export const defaultMultiInputMathExpressionConfig = (
  questionType: MultiInputQuestionType,
): MathExpressionQuestionConfig | undefined =>
  isMultiInputMathExpressionQuestionType(questionType)
    ? defaultMathExpressionConfig(questionType)
    : undefined;

export const multiInputStem = (input: InputRef) => ({
  id: guid(),
  content: [
    {
      type: 'p',
      id: guid(),
      children: [{ text: 'Example question with a fill in the blank ' }, input, { text: '.' }],
    } as Paragraph,
  ],
});

export const defaultModel = (): MultiInputSchema => {
  const input = Model.inputRef();

  return {
    stem: multiInputStem(input),
    choices: [],
    inputs: [{ inputType: 'text', id: input.id, partId: '1' }],
    submitPerPart: false,
    authoring: {
      parts: [makePart(Responses.forTextInput(), [makeHint('')], '1')],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle, true)],
      previewText: 'Example question with a fill in the blank',
    },
  };
};

export const friendlyType = (type: MultiInput['inputType']) => {
  if (type === 'dropdown') {
    return 'Dropdown';
  }

  switch (type) {
    case 'numeric':
      return 'Number';

    case 'math':
    case 'math_expression':
      return 'Math';

    case 'text':
    default:
      return 'Text';
  }
};

export const partTitle = (input: MultiInput, index: number) => (
  <div>
    {`Part ${index + 1}: `}
    <span className="text-muted">{friendlyType(input.inputType)}</span>
  </div>
);

// return part ids in order of input occurrence in stem
export const getOrderedPartIds = (model: MultiInputSchema) =>
  elementsOfType(model.stem.content, 'input_ref')
    .map((iref) => inputRefToPartId(model, iref))
    .filter(isDefined);

const inputRefToPartId = (model: MultiInputSchema, inputRef: any) =>
  model.inputs.find((input: any) => input.id === inputRef.id)?.partId;

export function guaranteeMultiInputValidity(model: MultiInputSchema): MultiInputSchema {
  // Check whether model is valid first to save unnecessarily cloning the model
  if (isValidModel(model)) {
    return model;
  }

  // Model must be cloned before being passed to these mutable functions.
  return ensureHasInput(
    matchInputsToChoices(matchInputsToParts(matchInputsToInputRefs(clone(model)))),
  );
}

function inputsMatchInputRefs(model: MultiInputSchema) {
  const inputRefs = elementsOfType(model.stem.content, 'input_ref');
  const union = setUnion(
    inputRefs.map(({ id }) => id),
    model.inputs.map(({ id }) => id),
  );
  return union.length === inputRefs.length && union.length === model.inputs.length;
}

function inputsMatchParts(model: MultiInputSchema) {
  const parts = model.authoring.parts;
  const union = setUnion(
    model.inputs.map(({ partId }) => partId),
    parts.map(({ id }) => id),
  );
  return union.length === model.inputs.length && union.length === parts.length;
}

function inputsMatchChoices(model: MultiInputSchema) {
  const inputChoiceIds = model.inputs.reduce(
    (acc, curr) => (curr.inputType === 'dropdown' ? acc.concat(curr.choiceIds) : acc),
    [] as string[],
  );
  const union = setUnion(
    model.choices.map(({ id }) => id),
    inputChoiceIds,
  );
  return union.length === model.choices.length && union.length === inputChoiceIds.length;
}

function hasAnInput(model: MultiInputSchema) {
  return model.inputs.length > 0;
}

function isValidModel(model: MultiInputSchema): boolean {
  return (
    hasAnInput(model) &&
    inputsMatchInputRefs(model) &&
    inputsMatchParts(model) &&
    inputsMatchChoices(model)
  );
}

function ensureHasInput(model: MultiInputSchema) {
  if (hasAnInput(model)) {
    return model;
  }

  // Make new input ref, add to first paragraph of stem, add new input to model.inputs,
  // add new part.
  const ref = Model.inputRef();
  const part = makePart(Responses.forTextInput(), [makeHint('')]);
  const input: MultiInput = { id: ref.id, inputType: 'text', partId: part.id };

  const firstParagraph = model.stem.content.find((elem) => elem.type === 'p') as
    | Paragraph
    | undefined;
  firstParagraph?.children.push(ref);
  firstParagraph?.children.push({ text: '' });

  model.inputs.push(input);
  model.authoring.parts.push(part);

  return model;
}

function matchInputsToChoices(model: MultiInputSchema) {
  if (inputsMatchChoices(model)) {
    return model;
  }

  const choiceIds = model.choices.map(({ id }) => id);
  const inputChoiceIds = model.inputs.reduce(
    (acc, curr) => (curr.inputType === 'dropdown' ? acc.concat(curr.choiceIds) : acc),
    [] as string[],
  );

  const unmatchedInputChoiceIds = setDifference(inputChoiceIds, choiceIds);

  const unmatchedChoices = setDifference(choiceIds, inputChoiceIds).map((id) =>
    model.choices.find((c) => c.id === id),
  );

  unmatchedInputChoiceIds.forEach((id) => {
    model.choices.push(makeChoice('Choice', id));
  });

  model.choices = model.choices.filter((choice) => !unmatchedChoices.includes(choice));

  return model;
}

function matchInputsToParts(model: MultiInputSchema) {
  if (inputsMatchParts(model)) {
    return model;
  }

  const inputIds = model.inputs.map(({ id }) => id);
  const partIds = model.authoring.parts.map(({ id }) => id);

  const unmatchedInputs = setDifference(inputIds, partIds).map((id) =>
    model.inputs.find((input) => input.id === id),
  );

  const unmatchedParts = setDifference(inputIds, partIds).map((id) =>
    model.authoring.parts.find((part) => part.id === id),
  );

  unmatchedInputs.forEach((input: MultiInput) => {
    const choices = [makeChoice('Choice A'), makeChoice('Choice B')];
    const part = makePart(
      input.inputType === 'dropdown'
        ? Responses.forMultipleChoice(choices[0].id)
        : input.inputType === 'numeric'
        ? Responses.forNumericInput()
        : input.inputType === 'math_expression'
        ? Responses.forMathExpression()
        : Responses.forTextInput(),
    );
    model.authoring.parts.push(part);
  });

  unmatchedParts.forEach((part: Part) => {
    const response = part.responses[0];
    const rule = response.rule ?? '';
    const isMathExpression = response.matchConfig?.type === 'math_expression';
    const type = rule.match(/{\d+}/) ? 'dropdown' : isTextRule(rule) ? 'text' : 'numeric';
    const ref = Model.inputRef();
    // If it's a dropdown, change the part to a text input.
    model.inputs.push({
      id: ref.id,
      inputType: isMathExpression ? 'math_expression' : type === 'dropdown' ? 'text' : type,
      partId: part.id,
    });
    part.responses = type === 'dropdown' ? Responses.forTextInput() : part.responses;
    // add inputRef to end of first paragraph in stem
    const firstParagraph = model.stem.content.find((elem) => elem.type === 'p') as
      | Paragraph
      | undefined;
    firstParagraph?.children.push(ref);
    firstParagraph?.children.push({ text: '' });
  });

  return model;
}

function matchInputsToInputRefs(model: MultiInputSchema) {
  if (inputsMatchInputRefs(model)) {
    return model;
  }

  const inputRefIds = elementsOfType(model.stem.content, 'input_ref').map(({ id }) => id);
  const inputIds = model.inputs.map(({ id }) => id);

  const unmatchedInputs = setDifference(inputIds, inputRefIds).map((id) =>
    model.inputs.find((input) => input.id === id),
  );

  const unmatchedInputRefs = setDifference(inputRefIds, inputIds).map(
    (id) => ({ id, type: 'input_ref' } as InputRef),
  );

  unmatchedInputs.forEach((input: MultiInput) => {
    // add inputRef to end of first paragraph in stem
    const firstParagraph = model.stem.content.find((e) => e.type === 'p') as Paragraph | undefined;
    firstParagraph?.children.push({ ...Model.inputRef(), id: input.id });
    firstParagraph?.children.push({ text: '' });
  });

  unmatchedInputRefs.forEach((ref) => {
    // create new input and part for the input ref in the stem
    const part = makePart(Responses.forTextInput(), [makeHint('')]);
    model.inputs.push({ id: ref.id, inputType: 'text', partId: part.id } as MultiInput);
    model.authoring.parts.push(part);
  });
  return model;
}
