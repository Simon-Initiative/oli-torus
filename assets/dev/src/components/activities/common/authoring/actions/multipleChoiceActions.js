import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { makeResponse, makeUndoable, } from 'components/activities/types';
import { Choices } from 'data/activities/model/choices';
import { getCorrectResponse, getResponseBy, getResponseId } from 'data/activities/model/responses';
import { matchRule } from 'data/activities/model/rules';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';
export const MCActions = {
    removeChoice(id, partId = DEFAULT_PART_ID) {
        return (model, post) => {
            const choice = Choices.getOne(model, id);
            const index = Choices.getAll(model).findIndex((c) => c.id === id);
            Choices.removeOne(id)(model);
            // if the choice being removed is the correct choice, a new correct choice
            // must be set
            const authoringClone = clone(model.authoring);
            if (getCorrectResponse(model, partId).rule === matchRule(id)) {
                const firstChoice = Choices.getAll(model)[0];
                MCActions.toggleChoiceCorrectness(firstChoice.id, partId)(model, post);
            }
            const undoable = makeUndoable('Removed a choice', [
                Operations.replace('$.authoring', authoringClone),
                Operations.insert(Choices.path, clone(choice), index),
            ]);
            post(undoable);
        };
    },
    toggleChoiceCorrectness(id, partId = DEFAULT_PART_ID) {
        return (model, _post) => {
            getCorrectResponse(model, partId).rule = matchRule(id);
        };
    },
    editTargetedFeedbackChoice(responseId, choiceId) {
        return (model, _post) => {
            const assoc = model.authoring.targeted.find((assoc) => getResponseId(assoc) === responseId);
            if (!assoc)
                return;
            assoc[0] = [choiceId];
            getResponseBy(model, (r) => r.id === getResponseId(assoc)).rule = matchRule(choiceId);
        };
    },
    addTargetedFeedback(partId = DEFAULT_PART_ID, choiceId) {
        return (model) => {
            const firstChoice = Choices.getAll(model)[0];
            const response = makeResponse(matchRule(choiceId || firstChoice.id), 0, '');
            // Insert new targeted response before the last response, which is the
            // catch-all incorrect response. Response rules are evaluated in-order,
            // so the catch-all should be the last response.
            ResponseActions.addResponse(response, partId)(model);
            model.authoring.targeted.push([[choiceId || firstChoice.id], response.id]);
        };
    },
};
//# sourceMappingURL=multipleChoiceActions.js.map