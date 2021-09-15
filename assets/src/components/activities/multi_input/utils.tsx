import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import {
  MultiInput,
  MultiInputSchema,
  MultiInputType,
} from 'components/activities/multi_input/schema';
import { makeHint, makePart, makeTransformation, Transform } from 'components/activities/types';
import { Responses } from 'data/activities/model/responses';
import { InputRef, inputRef, Paragraph } from 'data/content/model';
import React from 'react';
import guid from 'utils/guid';

export const multiInputOptions: SelectOption<'text' | 'numeric'>[] = [
  { value: 'numeric', displayValue: 'Number' },
  { value: 'text', displayValue: 'Text' },
];

export const multiInputStem = (input: InputRef) => ({
  id: guid(),
  content: {
    model: [
      {
        type: 'p',
        id: guid(),
        children: [{ text: 'Example question with a fill in the blank ' }, input, { text: '.' }],
      } as Paragraph,
    ],
    selection: null,
  },
});

export const defaultModel = (): MultiInputSchema => {
  const input = inputRef();

  return {
    stem: multiInputStem(input),
    choices: [],
    inputs: [{ inputType: 'text', id: input.id, partId: DEFAULT_PART_ID }],
    authoring: {
      parts: [makePart(Responses.forTextInput(), [makeHint('')], DEFAULT_PART_ID)],
      targeted: [],
      transformations: [makeTransformation('choices', Transform.shuffle)],
      previewText: 'Example question with a fill in the blank',
    },
  };
};

export const friendlyType = (type: MultiInputType) => {
  if (type === 'dropdown') {
    return 'Dropdown';
  }
  return `Input (${type === 'numeric' ? 'Number' : 'Text'})`;
};

export const partTitle = (input: MultiInput, index: number) => (
  <div>
    {`Part ${index + 1}: `}
    <span className="text-muted">{friendlyType(input.inputType)}</span>
  </div>
);
