import { makeResponse, } from 'components/activities/types';
import { containsRule, eqRule, matchRule } from 'data/activities/model/rules';
import { getByUnsafe, getPartById } from 'data/activities/model/utils';
import { Maybe } from 'tsmonad';
import { Operations } from 'utils/pathOperations';
export const Responses = {
    catchAll: (text = 'Incorrect') => makeResponse(matchRule('.*'), 0, text),
    forTextInput: (correctText = 'Correct', incorrectText = 'Incorrect') => [
        makeResponse(containsRule('answer'), 1, correctText),
        Responses.catchAll(incorrectText),
    ],
    forNumericInput: (correctText = 'Correct', incorrectText = 'Incorrect') => [
        makeResponse(eqRule('1'), 1, correctText),
        Responses.catchAll(incorrectText),
    ],
    forMultipleChoice: (correctChoiceId, correctText = 'Correct', incorrectText = 'Incorrect') => [
        makeResponse(matchRule(correctChoiceId), 1, correctText),
        makeResponse(matchRule('.*'), 0, incorrectText),
    ],
};
export const RESPONSES_PATH = '$..responses';
export const getResponses = (model, path = RESPONSES_PATH) => Operations.apply(model, Operations.find(path));
export const getResponsesByPartId = (model, partId) => getPartById(model, partId).responses;
export const getResponseBy = (model, predicate) => getByUnsafe(getResponses(model), predicate);
// Does not take into account partial credit
export const getCorrectResponse = (model, partId) => {
    return Maybe.maybe(getResponsesByPartId(model, partId).find((r) => r.score === 1)).valueOrThrow(new Error('Could not find correct response'));
};
export const getIncorrectResponse = (model, partId) => {
    return Maybe.maybe(getResponsesByPartId(model, partId).find((r) => r.rule === matchRule('.*'))).valueOrThrow(new Error('Could not find incorrect response'));
};
export const getTargetedResponseMappings = (model) => model.authoring.targeted.map((assoc) => ({
    response: getResponseBy(model, (r) => r.id === getResponseId(assoc)),
    choiceIds: getChoiceIds(assoc),
}));
// Choices
export const getChoiceIds = ([choiceIds]) => choiceIds;
export const getCorrectChoiceIds = (model) => getChoiceIds(model.authoring.correct);
export const getIncorrectChoiceIds = (model) => getChoiceIds(model.authoring.incorrect);
export const getTargetedChoiceIds = (model) => model.authoring.targeted.map(getChoiceIds);
export const isCorrectChoice = (model, choiceId) => getCorrectChoiceIds(model).includes(choiceId);
// Responses
export const getResponseId = ([, responseId]) => responseId;
export const getTargetedResponses = (model) => model.authoring.targeted.map((assoc) => getResponseBy(model, (r) => r.id === getResponseId(assoc)));
//# sourceMappingURL=responses.js.map