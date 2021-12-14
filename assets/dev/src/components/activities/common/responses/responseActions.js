import { remove } from 'components/activities/common/utils';
import { makeUndoable, } from 'components/activities/types';
import { getResponseBy, getResponseId, getResponsesByPartId, RESPONSES_PATH, } from 'data/activities/model/responses';
import { getParts } from 'data/activities/model/utils';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';
export const ResponseActions = {
    addResponse(response, partId, path = RESPONSES_PATH) {
        return (model) => {
            // Insert a new reponse just before the last response (which is the catch-all response)
            const responses = getResponsesByPartId(model, partId);
            getResponsesByPartId(model, partId).splice(responses.length - 1, 0, response);
        };
    },
    editResponseFeedback(responseId, content) {
        return (model) => {
            getResponseBy(model, (r) => r.id === responseId).feedback.content = content;
        };
    },
    removeResponse(responseId, path = RESPONSES_PATH) {
        return (model) => {
            getParts(model).forEach((part) => {
                if (part.responses.find(({ id }) => id === responseId)) {
                    part.responses = part.responses.filter(({ id }) => id !== responseId);
                }
            });
        };
    },
    editRule(id, rule) {
        return (draftState) => {
            getResponseBy(draftState, (r) => r.id === id).rule = rule;
        };
    },
    removeTargetedFeedback(responseId, path = RESPONSES_PATH) {
        return (model, post) => {
            post(makeUndoable('Removed feedback', [
                Operations.replace('$.authoring', clone(model.authoring)),
            ]));
            ResponseActions.removeResponse(responseId, path)(model);
            remove(model.authoring.targeted.find((assoc) => getResponseId(assoc) === responseId), model.authoring.targeted);
        };
    },
};
//# sourceMappingURL=responseActions.js.map