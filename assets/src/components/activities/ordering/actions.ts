import { RESPONSES_PATH } from '../../../data/activities/model/responseUtils';
import { OrderingSchema as Ordering } from './schema';
import {
  Choice,
  ResponseId,
  PostUndoable,
  makeUndoable,
  ChoiceId,
  makeResponse,
  Response,
} from 'components/activities/types';
import {
  getChoiceIds,
  getCorrectChoiceIds,
  getCorrectResponse,
  getResponseBy,
  getResponseId,
  getResponses,
} from 'data/activities/model/responseUtils';
import { DEFAULT_PART_ID, remove } from 'components/activities/common/utils';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { clone } from 'utils/common';
import jp from 'jsonpath';
import { matchInOrderRule } from 'data/activities/model/rules';
import { Operations } from 'utils/pathOperations';
import { getChoice, getChoices } from 'data/activities/model/choiceUtils';

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
        Operations.replace('$.authoring', clone(model.authoring)),
        Operations.insert('$.choices', clone(choice), index),
      ]);
      post(undoable);
    };
  }

  static addTargetedFeedback(path = RESPONSES_PATH) {
    return (model: Ordering) => {
      const choiceIds = model.choices.map((c: any) => c.id);
      const response = makeResponse(matchInOrderRule(choiceIds), 0, '');

      // Insert new targeted response before the last response, which is the
      // catch-all incorrect response. Response rules are evaluated in-order,
      // so the catch-all should be the last response.
      jp.apply(model, path, (responses: Response[]) => {
        responses.splice(getResponses(model).length - 1, 0, response);
        return responses;
      });
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
  getCorrectResponse(model, DEFAULT_PART_ID).rule = matchInOrderRule(getCorrectChoiceIds(model));

  model.authoring.targeted.forEach((assoc) => {
    getResponseBy(model, (r) => r.id === getResponseId(assoc)).rule = matchInOrderRule(
      getChoiceIds(assoc),
    );
  });
};
