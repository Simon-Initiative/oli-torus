import React from 'react';
import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { ResponseMultiInputSchema } from 'components/activities/response_multi/schema';
import {
  ChoiceId,
  Transform,
  makeHint,
  makePart,
  makeResponse,
  makeTransformation,
} from 'components/activities/types';
import { containsRule, eqRule, equalsRule, matchRule } from 'data/activities/model/rules';
import { Model } from 'data/content/model/elements/factories';
import { InputRef, Paragraph } from 'data/content/model/elements/types';
import guid from 'utils/guid';
import { MultiInput, MultiInputType } from '../multi_input/schema';
import { toInputRule } from './rules';

export const multiInputOptions: SelectOption<'text' | 'numeric'>[] = [
  { value: 'numeric', displayValue: 'Number' },
  { value: 'text', displayValue: 'Text' },
];

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

export const defaultRuleForInputType = (inputType: string | undefined, choiceId?: string) => {
  switch (inputType) {
    case 'numeric':
      return eqRule(0);
    case 'math':
      return equalsRule('');
    case 'dropdown':
      if (choiceId === undefined)
        throw new Error('choiceId paramenter required for dropdown input type');
      return matchRule(choiceId);
    case 'text':
    default:
      return containsRule('');
  }
};

export const ResponseMultiInputResponses = {
  catchAll: (inputId: string, text = 'Incorrect') => {
    const catchAllRespose = makeResponse(toInputRule(inputId, matchRule('.*')), 0, text);
    catchAllRespose.catchAll = true;
    return catchAllRespose;
  },
  forTextInput: (inputId: string, correctText = 'Correct', incorrectText = 'Incorrect') => [
    makeResponse(toInputRule(inputId, containsRule('answer')), 1, correctText),
    ResponseMultiInputResponses.catchAll(inputId, incorrectText),
  ],
  forNumericInput: (inputId: string, correctText = 'Correct', incorrectText = 'Incorrect') => [
    makeResponse(toInputRule(inputId, eqRule(1)), 1, correctText),
    ResponseMultiInputResponses.catchAll(inputId, incorrectText),
  ],
  forMathInput: (inputId: string, correctText = 'Correct', incorrectText = 'Incorrect') => [
    makeResponse(toInputRule(inputId, equalsRule('')), 1, correctText),
    ResponseMultiInputResponses.catchAll(inputId, incorrectText),
  ],
  forResponseMultipleChoice: (
    inputId: string,
    correctChoiceId: ChoiceId,
    correctText = 'Correct',
    incorrectText = 'Incorrect',
  ) => [
    makeResponse(toInputRule(inputId, matchRule(correctChoiceId)), 1, correctText),
    makeResponse(toInputRule(inputId, matchRule('.*')), 0, incorrectText),
  ],
};

export const defaultModel = (): ResponseMultiInputSchema => {
  const input = Model.inputRef();
  const partId = guid();

  return {
    stem: multiInputStem(input),
    choices: [],
    inputs: [{ inputType: 'text', id: input.id, partId: partId }],
    submitPerPart: false,
    multInputsPerPart: true,
    authoring: {
      parts: [
        makePart(ResponseMultiInputResponses.forTextInput(input.id), [makeHint('')], partId, [
          input.id,
        ]),
      ],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle, true)],
      previewText: 'Example question with a fill in the blank',
    },
  };
};

export const friendlyType = (type: MultiInputType) => {
  if (type === 'dropdown') {
    return 'Dropdown';
  }

  switch (type) {
    case 'numeric':
      return 'Number';

    case 'math':
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

export const inputTitle = (input: MultiInput, index: number) => (
  <div>
    {`Input ${index + 1}: `}
    <span className="text-muted">{friendlyType(input.inputType)}</span>
  </div>
);
