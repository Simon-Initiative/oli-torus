import { getByIdUnsafe } from 'components/activities/common/authoring/utils';
import { matchRule } from 'components/activities/common/responses/authoring/rules';
import { ChoiceId, ChoiceIdsToResponseId, HasParts, Response } from 'components/activities/types';
import { Maybe } from 'tsmonad';

// Responses
export const getResponses = (model: HasParts) => model.authoring.parts[0].responses;
export const getResponse = (model: HasParts, id: string) => getByIdUnsafe(getResponses(model), id);

export const getCorrectResponse = (model: HasParts) => {
  return Maybe.maybe(getResponses(model).find((r) => r.score === 1)).valueOrThrow(
    new Error('Could not find correct response'),
  );
};
export const getIncorrectResponse = (model: HasParts) => {
  return Maybe.maybe(getResponses(model).find((r) => r.rule === matchRule('.*'))).valueOrThrow(
    new Error('Could not find incorrect response'),
  );
};

export interface ResponseMapping {
  response: Response;
  choiceIds: ChoiceId[];
}
export const getTargetedResponseMappings = (
  model: HasParts & {
    authoring: { targeted: ChoiceIdsToResponseId[] };
  },
): ResponseMapping[] =>
  model.authoring.targeted.map((assoc) => ({
    response: getResponse(model, getResponseId(assoc)),
    choiceIds: getChoiceIds(assoc),
  }));

// Choices
export const getChoiceIds = ([choiceIds]: ChoiceIdsToResponseId) => choiceIds;
export const getCorrectChoiceIds = (model: { authoring: { correct: ChoiceIdsToResponseId } }) =>
  getChoiceIds(model.authoring.correct);
export const getIncorrectChoiceIds = (model: { authoring: { incorrect: ChoiceIdsToResponseId } }) =>
  getChoiceIds(model.authoring.incorrect);
export const getTargetedChoiceIds = (model: { authoring: { targeted: ChoiceIdsToResponseId[] } }) =>
  model.authoring.targeted.map(getChoiceIds);
export const isCorrectChoice = (
  model: { authoring: { correct: ChoiceIdsToResponseId } },
  choiceId: ChoiceId,
) => getCorrectChoiceIds(model).includes(choiceId);

// Responses
export const getResponseId = ([, responseId]: ChoiceIdsToResponseId) => responseId;
export const getTargetedResponses = (
  model: HasParts & { authoring: { targeted: ChoiceIdsToResponseId[] } },
) => model.authoring.targeted.map((assoc) => getResponse(model, getResponseId(assoc)));

// Update all response rules based on a model with new choices that
// are not yet reflected by the rules.
export const updateResponseRules = (
  model: HasParts & {
    authoring: { correct: ChoiceIdsToResponseId; targeted: ChoiceIdsToResponseId[] };
  },
  ruleFactory: (...args: any[]) => string,
) => {
  getCorrectResponse(model).rule = ruleFactory(getCorrectChoiceIds(model));
  model.authoring.targeted.forEach((assoc) => {
    getResponse(model, getResponseId(assoc)).rule = ruleFactory(getChoiceIds(assoc));
  });
};
