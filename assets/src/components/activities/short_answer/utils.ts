import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { InputType, ShortAnswerModelSchema } from 'components/activities/short_answer/schema';
import {
  getCorrectResponse,
  getIncorrectResponse,
  getResponsesByPartId,
  Responses,
} from 'data/activities/model/responses';
import { HasParts, makeHint, makeStem, ScoringStrategy } from '../types';

export const defaultModel: () => ShortAnswerModelSchema = () => {
  return {
    stem: makeStem(''),
    inputType: 'text',
    authoring: {
      parts: [
        {
          id: DEFAULT_PART_ID,
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

export const getTargetedResponses = (model: HasParts, partId: string) =>
  getResponsesByPartId(model, partId).filter(
    (response) =>
      response !== getCorrectResponse(model, partId) &&
      response !== getIncorrectResponse(model, partId),
  );

export const shortAnswerOptions: SelectOption<InputType>[] = [
  { value: 'numeric', displayValue: 'Number' },
  { value: 'text', displayValue: 'Short Text' },
  { value: 'textarea', displayValue: 'Paragraph' },
  { value: 'math', displayValue: 'Math' },
];
