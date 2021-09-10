import {
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
import guid from 'utils/guid';
import { InputRef, Paragraph } from 'data/content/model';

export const multiInputOptions: SelectOption<'text' | 'numeric'>[] = [
  { value: 'numeric', displayValue: 'Number' },
  { value: 'text', displayValue: 'Text' },
];

export const multiInputChoicesPath = (partId: string) => `$.inputs[?(@.partId==${partId})].choices`;

export const defaultModel = (): MultiInputSchema => {
  return {
    stem: {
      id: guid(),
      content: {
        model: [
          {
            type: 'p',
            id: guid(),
            children: [
              { text: 'Example question with a fill in the blank ' },
              {
                type: 'input_ref',
                id: guid(),
                inputType: 'text',
                partId: DEFAULT_PART_ID,
                children: [{ text: '' }],
              } as InputRef,
              { text: '.' },
            ],
          } as Paragraph,
        ],
        selection: null,
      },
    },
    choices: [],
    // inputs: [{ type: 'text', id: guid(), partId: DEFAULT_PART_ID }],
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
