import {
  makeStem,
  makeTransformation,
  Transform,
  ScoringStrategy,
  makeResponse,
  makeHint,
} from 'components/activities/types';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { containsRule, matchRule } from 'data/activities/model/rules';
import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { MultiInputSchema } from 'components/activities/multi_input/schema';

export const multiInputOptions: SelectOption<'text' | 'numeric'>[] = [
  { value: 'numeric', displayValue: 'Number' },
  { value: 'text', displayValue: 'Text' },
];

export const multiInputChoicesPath = (partId: string) => `$.inputs[?(@.partId==${partId})].choices`;

export const defaultModel = (): MultiInputSchema => {
  return {
    stems: [makeStem(''), makeStem('')],
    choices: [],
    inputs: [{ type: 'text', partId: DEFAULT_PART_ID }],
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
      transformations: [makeTransformation('choices', Transform.shuffle)],
      previewText: '',
    },
  };
};
