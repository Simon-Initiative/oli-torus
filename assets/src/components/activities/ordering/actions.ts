import { OrderingSchema as Ordering } from './schema';
import { Choice, ResponseId, PostUndoable, makeUndoable, ChoiceId, makeResponse } from '../types';
import { createRuleForIdsOrdering } from 'components/activities/ordering/utils';
import {
  getChoiceIds,
  getCorrectChoiceIds,
  getCorrectResponse,
  getResponse,
  getResponseId,
  getResponses,
} from 'components/activities/common/responses/authoring/responseUtils';
import { remove } from 'components/activities/common/utils';
import { getChoice, getChoices } from 'components/activities/common/choices/authoring/choiceUtils';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { clone } from 'utils/common';

export class Actions {
  static addChoice(choice: Choice) {
    return (model: Ordering) => {
      model.choices.push(choice);
      getCorrectChoiceIds(model).push(choice.id);

      model.authoring.targeted.forEach((assoc: any) => getChoiceIds(assoc).push(choice.id));
      updateResponseRules(model);
    };
  }

  static setCorrectChoices(choices: Choice[]) {
    return (model: Ordering) => {
      model.authoring.correct[0] = choices.map((c) => c.id);
      updateResponseRules(model);
    };
  }

  static removeChoiceAndUpdateRules(id: string) {
    return (model: Ordering, post: PostUndoable) => {
      const choice = getChoice(model, id);
      const index = getChoices(model).findIndex((c) => c.id === id);
      ChoiceActions.removeChoice(id)(model, post);

      remove(id, getChoiceIds(model.authoring.correct));
      model.authoring.targeted.forEach((assoc: any) => remove(id, getChoiceIds(assoc)));

      updateResponseRules(model);

      const undoable = makeUndoable('Removed a choice', [
        { type: 'ReplaceOperation', path: '$.authoring', item: clone(model.authoring) },
        { type: 'InsertOperation', path: '$.choices', index, item: clone(choice) },
      ]);
      post(undoable);
    };
  }

  static addTargetedFeedback() {
    return (model: Ordering) => {
      const choiceIds = model.choices.map((c: any) => c.id);
      const response = makeResponse(createRuleForIdsOrdering(choiceIds), 0, '');

      // Insert new targeted response before the last response, which is the
      // catch-all incorrect response. Response rules are evaluated in-order,
      // so the catch-all should be the last response.
      getResponses(model).splice(getResponses(model).length - 1, 0, response);
      model.authoring.targeted.push([choiceIds, response.id]);
    };
  }

  static editTargetedFeedbackChoices(responseId: ResponseId, choiceIds: ChoiceId[]) {
    return (model: Ordering) => {
      const assoc = model.authoring.targeted.find(
        (assoc: any) => getResponseId(assoc) === responseId,
      );
      if (!assoc) return;
      assoc[0] = choiceIds;
      updateResponseRules(model);
    };
  }
}

// Update all response rules based on a model with new choices that
// are not yet reflected by the rules.
const updateResponseRules = (model: Ordering) => {
  getCorrectResponse(model).rule = createRuleForIdsOrdering(getCorrectChoiceIds(model));

  model.authoring.targeted.forEach((assoc: any) => {
    getResponse(model, getResponseId(assoc)).rule = createRuleForIdsOrdering(getChoiceIds(assoc));
  });
};
