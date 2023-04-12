import { HasParts, ScoringStrategy, makeHint, makeStem } from '../types';
import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { InputType, ShortAnswerModelSchema } from 'components/activities/short_answer/schema';
import {
  Responses,
  getCorrectResponse,
  getIncorrectResponse,
  getResponsesByPartId,
} from 'data/activities/model/responses';

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

// disable changing of the value via scroll wheel in certain browsers
export const disableScrollWheelChange = (numericInput: React.RefObject<HTMLInputElement>) => () =>
  numericInput.current?.blur();
