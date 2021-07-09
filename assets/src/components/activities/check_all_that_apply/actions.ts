import { CATASchema as CATA } from './schema';
import { ChoiceId, Choice, ResponseId, PostUndoable, makeResponse } from '../types';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { addOrRemove, remove } from 'components/activities/common/utils';
import {
  getChoiceIds,
  getCorrectChoiceIds,
  getCorrectResponse,
  getResponse,
  getResponseId,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';
import { createRuleForIdsCATA } from 'components/activities/check_all_that_apply/utils';
import { getChoice, getChoices } from 'components/activities/common/choices/authoring/choiceUtils';

export class CATAActions {
  static addChoice(choice: Choice) {
    return (model: CATA, post: PostUndoable) => {
      ChoiceActions.addChoice(choice)(model, post);

      updateResponseRules(model);
    };
  }

  static toggleChoiceCorrectness(choiceId: ChoiceId) {
    return (model: CATA) => {
      addOrRemove(choiceId, getChoiceIds(model.authoring.correct));
      updateResponseRules(model);
    };
  }

  static removeChoiceAndUpdateRules(id: string) {
    return (model: CATA, post: PostUndoable) => {
      const choice = getChoice(model, id);
      const index = getChoices(model).findIndex((c) => c.id === id);
      ChoiceActions.removeChoice(id)(model, post);

      remove(id, getChoiceIds(model.authoring.correct));
      model.authoring.targeted.forEach((assoc) => remove(id, getChoiceIds(assoc)));

      updateResponseRules(model);

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
  }

  static addTargetedFeedback() {
    return (model: CATA) => {
      const choiceIds = model.choices.map((c) => c.id);
      const response = makeResponse(createRuleForIdsCATA(choiceIds, []), 0, '');

      // Insert new targeted response before the last response, which is the
      // catch-all incorrect response. Response rules are evaluated in-order,
      // so the catch-all should be the last response.
      getResponses(model).splice(getResponses(model).length - 1, 0, response);
      model.authoring.targeted.push([[], response.id]);
    };
  }

  static editTargetedFeedbackChoices(responseId: ResponseId, choiceIds: ChoiceId[]) {
    return (model: CATA) => {
      const assoc = model.authoring.targeted.find((assoc) => getResponseId(assoc) === responseId);
      if (!assoc) return;
      assoc[0] = choiceIds;
      updateResponseRules(model);
    };
  }
}

// Update all response rules based on a model with new choices that
// are not yet reflected by the rules.
const updateResponseRules = (model: CATA) => {
  getCorrectResponse(model).rule = createRuleForIdsCATA(
    model.choices.map((c) => c.id),
    getCorrectChoiceIds(model),
  );

  model.authoring.targeted.forEach((assoc) => {
    getResponse(model, getResponseId(assoc)).rule = createRuleForIdsCATA(
      model.choices.map((c) => c.id),
      getChoiceIds(assoc),
    );
  });
};
