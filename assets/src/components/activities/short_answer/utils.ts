import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { InputType, ShortAnswerModelSchema } from 'components/activities/short_answer/schema';
import {
  Responses,
  getCorrectResponse,
  getIncorrectResponse,
  getResponsesByPartId,
} from 'data/activities/model/responses';
import {
  HasParts,
  ScoringStrategy,
  makeHint,
  makeStem,
  CreationData,
  Hint,
  makeResponse,
  Part,
  makePart, makeFeedback,
} from '../types';
import { containsRule, eqRule, equalsRule, matchRule } from 'data/activities/model/rules';

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

export const sAModel: (creationData: CreationData) => ShortAnswerModelSchema = (creationData: CreationData) => {

  const hints: Hint[] = Object.entries(creationData).filter(([key, value]) => key.startsWith('hint') && value).map(([_key, value]) => {
    return makeHint(value as string);
  });

  const correctFeedback = creationData.correct_feedback ? creationData.correct_feedback : 'Correct';
  const incorrectFeedback = creationData.incorrect_feedback ? creationData.incorrect_feedback : 'Incorrect';

  let response  = Responses.forTextInput();
  let inputType: InputType = 'text';
  switch (creationData.type.toLowerCase()) {
    case 'number':
      response = [makeResponse(eqRule(creationData.answer), 1, correctFeedback, true),
        Responses.catchAll(incorrectFeedback)];
      inputType = 'numeric';
      break;
    case 'text':
      response =  [makeResponse(containsRule(creationData.answer), 1, correctFeedback, true),
        Responses.catchAll(incorrectFeedback)];
      inputType = 'text';
      break;
    case 'paragraph':
      response = [makeResponse(matchRule('.*'), 0, 'correct', true)]
      inputType = 'textarea';
      break;
    case 'math':
      response = [makeResponse(equalsRule(creationData.answer), 1, correctFeedback, true),
        Responses.catchAll(incorrectFeedback)]
      inputType = 'math';
      break;
    default:
      break;
  }

  const part: Part = {
    id: '1',
    scoringStrategy: ScoringStrategy.average,
    responses: response,
    hints: hints,
  };

  if (creationData.explanation) {
    part.explanation = makeFeedback(creationData.explanation);
  }

  const stem = creationData.stem ? creationData.stem : '';
  return {
    stem: makeStem(stem),
    inputType: inputType,
    authoring: {
      parts: [
        part,
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
