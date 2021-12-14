import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { addOrRemove, DEFAULT_PART_ID, remove } from 'components/activities/common/utils';
import { Choices } from 'data/activities/model/choices';
import { getChoiceIds, getCorrectChoiceIds, getCorrectResponse, getResponseBy, getResponseId, } from 'data/activities/model/responses';
import { matchListRule } from 'data/activities/model/rules';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';
import { makeResponse, makeUndoable } from '../types';
export const CATAActions = {
    addChoice(choice) {
        return (model, post) => {
            Choices.addOne(choice)(model);
            updateResponseRules(model);
        };
    },
    toggleChoiceCorrectness(choiceId) {
        return (model) => {
            addOrRemove(choiceId, getChoiceIds(model.authoring.correct));
            updateResponseRules(model);
        };
    },
    removeChoiceAndUpdateRules(id) {
        return (model, post) => {
            post(makeUndoable('Removed choice', [
                Operations.replace('$.authoring', clone(model.authoring)),
                Operations.replace('$.choices', clone(model.choices)),
            ]));
            Choices.removeOne(id)(model);
            remove(id, getChoiceIds(model.authoring.correct));
            model.authoring.targeted.forEach((assoc) => remove(id, getChoiceIds(assoc)));
            updateResponseRules(model);
        };
    },
    addTargetedFeedback() {
        return (model) => {
            const choiceIds = Choices.getAll(model).map((c) => c.id);
            const response = makeResponse(matchListRule(choiceIds, []), 0, '');
            ResponseActions.addResponse(response, DEFAULT_PART_ID)(model);
            model.authoring.targeted.push([[], response.id]);
        };
    },
    editTargetedFeedbackChoices(responseId, choiceIds) {
        return (model) => {
            const assoc = model.authoring.targeted.find((assoc) => getResponseId(assoc) === responseId);
            if (!assoc)
                return;
            assoc[0] = choiceIds;
            updateResponseRules(model);
        };
    },
};
// Update all response rules based on a model with new choices that
// are not yet reflected by the rules.
const updateResponseRules = (model) => {
    getCorrectResponse(model, DEFAULT_PART_ID).rule = matchListRule(model.choices.map((c) => c.id), getCorrectChoiceIds(model));
    model.authoring.targeted.forEach((assoc) => {
        getResponseBy(model, (r) => r.id === getResponseId(assoc)).rule = matchListRule(model.choices.map((c) => c.id), getChoiceIds(assoc));
    });
};
//# sourceMappingURL=actions.js.map