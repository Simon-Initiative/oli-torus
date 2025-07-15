import { Maybe } from 'tsmonad';
import * as MultiRule from 'components/activities/response_multi/rules';
import {
  ActivityLevelScoring,
  ChoiceId,
  ChoiceIdsToResponseId,
  HasParts,
  Part,
  Response,
  makeResponse,
} from 'components/activities/types';
import { containsRule, eqRule, equalsRule, matchRule } from 'data/activities/model/rules';
import { getByUnsafe, getPartById } from 'data/activities/model/utils';

export const Responses = {
  catchAll: (text = 'Incorrect') => makeResponse(matchRule('.*'), 0, text),
  forTextInput: (correctText = 'Correct', incorrectText = 'Incorrect') => [
    makeResponse(containsRule('answer'), 1, correctText, true),
    Responses.catchAll(incorrectText),
  ],
  forNumericInput: (correctText = 'Correct', incorrectText = 'Incorrect') => [
    makeResponse(eqRule(1), 1, correctText, true),
    Responses.catchAll(incorrectText),
  ],
  forMathInput: (correctText = 'Correct', incorrectText = 'Incorrect') => [
    makeResponse(equalsRule(''), 1, correctText, true),
    Responses.catchAll(incorrectText),
  ],
  forMultipleChoice: (
    correctChoiceId: ChoiceId,
    correctText = 'Correct',
    incorrectText = 'Incorrect',
  ) => [
    makeResponse(matchRule(correctChoiceId), 1, correctText, true),
    makeResponse(matchRule('.*'), 0, incorrectText),
  ],
};

export const RESPONSES_PATH = '$..responses';
export const getResponses = (model: HasParts): Response[] =>
  model.authoring.parts.map((p) => p.responses).flat();

export const getResponsesByPartId = (model: HasParts, partId: string): Response[] =>
  getPartById(model, partId).responses;

export const getResponseBy = (model: HasParts, predicate: (x: Response) => boolean) =>
  getByUnsafe(getResponses(model), predicate);

// Use of custom scoring is explicitly flagged to authoring differently in
// single-part and multi-part activities. However, older migrations did not set
// these flags, so these routines also allow it to be implicit in the use of
// non-default point values.

// single-part questions flag by non-nullish outOf attribute in the part
export const hasCustomScoring = (model: HasParts, partId?: string): boolean => {
  const pId = partId || model.authoring.parts[0].id;
  const outOf = getPartById(model, pId)?.outOf;
  // migrated qs may carry non-default point values but no outOf attribute
  const maxScore = getMaxPoints(model, pId);
  return (outOf !== null && outOf !== undefined) || maxScore > 1;
};

// multi-part activities use activity-wide customScoring flag
export const multiHasCustomScoring = (model: ActivityLevelScoring) =>
  model.customScoring ||
  // migrated qs may carry non-default point values but no customScoring attribute.
  model.authoring.parts.some((part: Part) => part.responses.some((r: Response) => r.score > 1));

export const getOutOfPoints = (model: HasParts, partId: string) => {
  const outOf = getPartById(model, partId)?.outOf;
  // migrated qs may carry non-default point values but no  attribute
  return outOf ?? getMaxPoints(model, partId);
};

export const getScoringStrategy = (model: HasParts, partId: string) => {
  const part = getPartById(model, partId);
  return part?.scoringStrategy;
};

export const getIncorrectPoints = (model: HasParts, partId: string) => {
  const part = getPartById(model, partId);
  return part?.incorrectScore ?? 0;
};

export const getCorrectResponse = (model: HasParts, partId: string) => {
  return Maybe.maybe(
    getResponsesByPartId(model, partId).find((r) => r.correct) ||
      getMaxScoreResponse(model, partId),
  ).valueOrThrow(new Error('Could not find correct response'));
};

export const getIncorrectResponse = (model: HasParts, partId: string) => {
  return Maybe.maybe(
    getResponsesByPartId(model, partId).find((r) => {
      return (
        // check score for edge case where author sets a correct response of .*
        r.score === getIncorrectPoints(model, partId) &&
        (r.rule === matchRule('.*') ||
          // Allow for special rule form used by ResponseMulti
          (r.rule.startsWith('input_ref') && MultiRule.ruleIsCatchAll(r.rule)))
      );
    }),
  ).valueOrThrow(new Error('Could not find incorrect response'));
};

export const getMaxScoreResponse = (model: HasParts, partId: string) => {
  return getResponsesByPartId(model, partId).reduce((prev, current) =>
    // in case of ties, use first one found as "primary" correct answer
    prev && current.score > prev.score ? current : prev,
  );
};

export const getMaxPoints = (model: HasParts, partId: string) =>
  getMaxScoreResponse(model, partId).score;

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

// extract targeted from response list without any reliance on targeted mapping
export const findTargetedResponses = (model: HasParts, partId: string) => {
  const responses = getResponsesByPartId(model, partId);
  const correct = getCorrectResponse(model, partId);
  const incorrect = getIncorrectResponse(model, partId);

  return responses.filter((r) => r !== correct && r !== incorrect);
};
