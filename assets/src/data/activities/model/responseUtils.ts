import { getByUnsafe } from 'components/activities/common/authoring/utils';
import { matchRule } from 'components/activities/common/responses/authoring/rules';
import { ChoiceId, ChoiceIdsToResponseId, HasParts, Response } from 'components/activities/types';
import { Maybe } from 'tsmonad';
import jp from 'jsonpath';
import { Operations } from 'utils/pathOperations';

// Responses

export const RESPONSES_PATH = '$..responses';
export const getResponses = (model: HasParts, path = RESPONSES_PATH): Response[] =>
  jp.query(model, path).reduce((acc, partResponses) => acc.concat(partResponses), []);

export const RESPONSES_BY_PART_ID_PATH = (partId: string) =>
  `$..parts[?(@.id==${partId})].responses`;
export const getResponsesByPartId = (
  model: any,
  partId: string,
  path: string | ((partId: string) => string) = RESPONSES_BY_PART_ID_PATH,
): Response[] =>
  Operations.apply(model, Operations.find(typeof path === 'function' ? path(partId) : path));

export const getResponseBy = (model: HasParts, predicate: (x: Response) => boolean) =>
  getByUnsafe(getResponses(model), predicate);

// Does not take into account partial credit
export const getCorrectResponse = (model: HasParts, partId: string) => {
  return Maybe.maybe(getResponsesByPartId(model, partId).find((r) => r.score === 1)).valueOrThrow(
    new Error('Could not find correct response'),
  );
};
export const getIncorrectResponse = (model: HasParts, partId: string) => {
  return Maybe.maybe(
    getResponsesByPartId(model, partId).find((r) => r.rule === matchRule('.*')),
  ).valueOrThrow(new Error('Could not find incorrect response'));
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
    response: getResponseBy(model, (r) => r.id === getResponseId(assoc)),
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
) =>
  model.authoring.targeted.map((assoc) =>
    getResponseBy(model, (r) => r.id === getResponseId(assoc)),
  );
