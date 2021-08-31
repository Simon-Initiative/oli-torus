import { MultiInputSchema } from './schema';
import {
  makeStem,
  makeTransformation,
  Operation,
  Choice,
  ScoringStrategy,
  makeResponse,
  makeHint,
} from 'components/activities/types';
import { assertNever } from 'utils/common';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { containsRule, matchRule } from 'data/activities/model/rules';
import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';

export type MultiInput = MultiDropdownInput | MultiTextInput;

export type MultiDropdownInput = {
  type: 'dropdown';
  partId: string;
  choices: Choice[];
};
export const makeMultiDropdownInput = (choices: Choice[], partId: string): MultiDropdownInput => ({
  type: 'dropdown',
  partId,
  choices,
});
export type MultiTextInput = {
  type: 'text' | 'numeric';
  partId: string;
};
export const makeMultiTextInput = (type: 'text' | 'numeric', partId: string): MultiTextInput => ({
  type,
  partId,
});
export type MultiInputType = 'dropdown' | 'text' | 'numeric';
export const multiInputTypes: MultiInputType[] = ['dropdown', 'text', 'numeric'];

export const multiInputTypeFriendly = (type: MultiInputType): string => {
  switch (type) {
    case 'dropdown':
      return 'Dropdown';
    case 'numeric':
      return 'Number';
    case 'text':
      return 'Text';
    default:
      assertNever(type);
  }
};

export const multiInputOptions: SelectOption<'text' | 'numeric'>[] = [
  { value: 'numeric', displayValue: 'Number' },
  { value: 'text', displayValue: 'Text' },
];

export const multiInputChoicesPath = (partId: string) => `$.inputs[?(@.partId==${partId})].choices`;

export const defaultModel = (): MultiInputSchema => {
  return {
    stems: [makeStem(''), makeStem('')],
    inputs: [makeMultiTextInput('text', DEFAULT_PART_ID)],
    authoring: {
      parts: [
        {
          id: DEFAULT_PART_ID,
          scoringStrategy: ScoringStrategy.average,
          responses: [
            makeResponse(containsRule('answer'), 1, ''),
            makeResponse(matchRule('.*'), 0, ''),
          ],
          hints: [makeHint('')],
        },
      ],
      targeted: [],
      transformations: [makeTransformation('choices', Operation.shuffle)],
      previewText: '',
    },
  };
};

// export const joinStems = (model: MultiInputSchema)
