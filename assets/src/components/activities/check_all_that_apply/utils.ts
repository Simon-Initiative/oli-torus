import {
  CheckAllThatApplyModelSchema as CATA,
  ChoiceIdsToResponseId,
  TargetedCATA,
  SimpleCATA,
} from './schema';
import {
  ChoiceId,
  makeChoice,
  makeHint,
  makeResponse,
  makeStem,
  makeTransformation,
  Operation,
  Response,
  ScoringStrategy,
} from 'components/activities/types';
import {
  createRuleForIds,
  invertRule,
} from 'components/activities/common/responses/authoring/rules';
import { getResponse } from 'components/activities/common/responses/authoring/responseUtils';
import { TargetedOrdering } from 'components/activities/ordering/schema';

// Types
export function isSimpleCATA(model: CATA): model is SimpleCATA {
  return model.type === 'SimpleCATA';
}
export function isTargetedCATA(model: CATA): model is TargetedCATA {
  return model.type === 'TargetedCATA';
}

// Choices
export const getChoiceIds = ([choiceIds]: ChoiceIdsToResponseId) => choiceIds;
export const getCorrectChoiceIds = (model: CATA) => getChoiceIds(model.authoring.correct);
export const getIncorrectChoiceIds = (model: CATA) => getChoiceIds(model.authoring.incorrect);
export const getTargetedChoiceIds = (model: TargetedCATA | TargetedOrdering) =>
  model.authoring.targeted.map(getChoiceIds);
export const isCorrectChoice = (model: CATA, choiceId: ChoiceId) =>
  getCorrectChoiceIds(model).includes(choiceId);

// Responses
export const getResponseId = ([, responseId]: ChoiceIdsToResponseId) => responseId;
export const getCorrectResponse = (model: CATA) =>
  getResponse(model, getResponseId(model.authoring.correct));
export const getIncorrectResponse = (model: CATA) =>
  getResponse(model, getResponseId(model.authoring.incorrect));
export const getTargetedResponses = (model: TargetedCATA | TargetedOrdering) =>
  model.authoring.targeted.map((assoc) => getResponse(model, getResponseId(assoc)));

export interface ResponseMapping {
  response: Response;
  choiceIds: ChoiceId[];
}
export const getTargetedResponseMappings = (
  model: TargetedCATA | TargetedOrdering,
): ResponseMapping[] =>
  model.authoring.targeted.map((assoc) => ({
    response: getResponse(model, getResponseId(assoc)),
    choiceIds: getChoiceIds(assoc),
  }));

// Model creation
export const defaultCATAModel = (): CATA => {
  const correctChoice = makeChoice('Choice 1');
  const incorrectChoice = makeChoice('Choice 2');

  const correctResponse = makeResponse(
    createRuleForIds([correctChoice.id], [incorrectChoice.id]),
    1,
    '',
  );
  const incorrectResponse = makeResponse(invertRule(correctResponse.rule), 0, '');

  return {
    type: 'SimpleCATA',
    stem: makeStem(''),
    choices: [correctChoice, incorrectChoice],
    authoring: {
      parts: [
        {
          id: '1', // a only has one part, so it is safe to hardcode the id
          scoringStrategy: ScoringStrategy.average,
          responses: [correctResponse, incorrectResponse],
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      correct: [[correctChoice.id], correctResponse.id],
      incorrect: [[incorrectChoice.id], incorrectResponse.id],
      transformations: [makeTransformation('choices', Operation.shuffle)],
      previewText: '',
    },
  };
};
