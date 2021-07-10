import { MCSchema } from './schema';
import { ChoiceId, makeResponse, PostUndoable, ResponseId } from 'components/activities/types';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { getChoice, getChoices } from 'components/activities/common/choices/authoring/choiceUtils';
import { matchRule } from 'components/activities/common/responses/authoring/rules';
import {
  getCorrectResponse,
  getResponse,
  getResponseId,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';

export const MCActions = {
  removeChoice(id: string) {
    return (model: MCSchema, post: PostUndoable) => {
      const choice = getChoice(model, id);
      const index = getChoices(model).findIndex((c) => c.id === id);
      ChoiceActions.removeChoice(id)(model, post);

      // if the choice being removed is the correct choice, a new correct choice
      // must be set
      if (getCorrectResponse(model).rule === matchRule(id)) {
        MCActions.toggleChoiceCorrectness(model.choices[0].id)(model, post);
      }

      post({
        description: 'Removed a choice',
        operations: [
          {
            path: '$.choices',
            index,
            item: JSON.parse(JSON.stringify(choice)),
          },
        ],
        type: 'Undoable',
      });
    };
  },

  toggleChoiceCorrectness(id: string) {
    return (model: MCSchema, post: PostUndoable) => {
      getCorrectResponse(model).rule = matchRule(id);
    };
  },

  editTargetedFeedbackChoice(responseId: ResponseId, choiceId: ChoiceId) {
    return (model: MCSchema, post: PostUndoable) => {
      const assoc = model.authoring.targeted.find((assoc) => getResponseId(assoc) === responseId);
      if (!assoc) return;
      assoc[0] = [choiceId];
      getResponse(model, getResponseId(assoc)).rule = matchRule(choiceId);
    };
  },

  addTargetedFeedback() {
    return (model: MCSchema, post: PostUndoable) => {
      const firstChoiceId = model.choices[0].id;
      const response = makeResponse(matchRule(firstChoiceId), 0, '');

      // Insert new targeted response before the last response, which is the
      // catch-all incorrect response. Response rules are evaluated in-order,
      // so the catch-all should be the last response.
      getResponses(model).splice(getResponses(model).length - 1, 0, response);
      model.authoring.targeted.push([[firstChoiceId], response.id]);
    };
  },
};
