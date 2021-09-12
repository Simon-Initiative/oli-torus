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
import {
  MultiInput,
  MultiInputSchema,
  MultiInputType,
} from 'components/activities/multi_input/schema';
import guid from 'utils/guid';
import { inputRef, Paragraph } from 'data/content/model';

export const multiInputOptions: SelectOption<'text' | 'numeric'>[] = [
  { value: 'numeric', displayValue: 'Number' },
  { value: 'text', displayValue: 'Text' },
];

export const defaultModel = (): MultiInputSchema => {
  const input = inputRef();

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
              input,
              { text: '.' },
            ],
          } as Paragraph,
        ],
        selection: null,
      },
    },
    choices: [],
    inputs: [{ inputType: 'text', id: input.id, partId: DEFAULT_PART_ID }],
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

export const friendlyType = (type: MultiInputType) => {
  if (type === 'dropdown') {
    return 'Dropdown';
  }
  return `Input (${type === 'numeric' ? 'Number' : 'Text'})`;
};

export const inputNumberings = (inputs: MultiInput[]): { type: string; number: number }[] => {
  return inputs.reduce(
    (acc, input) => {
      const type = friendlyType(input.inputType);

      if (!acc.seenCount[type]) {
        acc.seenCount[type] = 1;
        acc.numberings.push({ type, number: 1 });
        return acc;
      }
      acc.seenCount[type] = acc.seenCount[type] + 1;
      acc.numberings.push({ type, number: acc.seenCount[type] });
      return acc;
    },
    { seenCount: {}, numberings: [] } as any,
  ).numberings;
};

export const friendlyTitle = (numbering: any) => {
  return numbering.type + ' ' + numbering.number;
};
