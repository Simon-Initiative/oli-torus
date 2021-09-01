import { HasParts, makeHint, makeResponse, makeStem, ScoringStrategy } from '../types';
import { containsRule, matchRule } from 'data/activities/model/rules';
import {
  getCorrectResponse,
  getIncorrectResponse,
  getResponses,
} from 'data/activities/model/responseUtils';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { InputType, ShortAnswerModelSchema } from 'components/activities/short_answer/schema';

export const defaultModel: () => ShortAnswerModelSchema = () => {
  return {
    stem: makeStem(''),
    inputType: 'text',
    authoring: {
      parts: [
        {
          id: DEFAULT_PART_ID,
          scoringStrategy: ScoringStrategy.average,
          responses: [
            makeResponse(containsRule('answer'), 1, ''),
            makeResponse(matchRule('.*'), 0, ''),
          ],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      transformations: [],
      previewText: '',
    },
  };
};

export const getTargetedResponses = (model: HasParts, partId: string) =>
  getResponses(model).filter(
    (response) =>
      response !== getCorrectResponse(model, partId) &&
      response !== getIncorrectResponse(model, partId),
  );

export const shortAnswerOptions: SelectOption<InputType>[] = [
  { value: 'numeric', displayValue: 'Number' },
  { value: 'text', displayValue: 'Short Text' },
  { value: 'textarea', displayValue: 'Paragraph' },
];
