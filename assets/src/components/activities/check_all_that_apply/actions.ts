import { CATASchema as CATA } from './schema';
import { ChoiceId, Choice, ResponseId, PostUndoable, makeResponse, makeUndoable } from '../types';
import { ChoiceActions } from 'components/activities/common/choices/authoring/choiceActions';
import { DEFAULT_PART_ID, addOrRemove, remove } from 'components/activities/common/utils';
import {
  getChoiceIds,
  getCorrectChoiceIds,
  getCorrectResponse,
  getResponseBy,
  getResponseId,
} from 'data/activities/model/responseUtils';
import { clone } from 'utils/common';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { matchListRule } from 'data/activities/model/rules';
import { Operations } from 'utils/pathOperations';

export const CATAActions = {
  addChoice(choice: Choice, choicesPath = CHOICES_PATH) {
    return (model: CATA, post: PostUndoable) => {
      ChoiceActions.addChoice(choice, choicesPath)(model, post);
      updateResponseRules(model);
    };
  },

  toggleChoiceCorrectness(choiceId: ChoiceId) {
    return (model: CATA) => {
      addOrRemove(choiceId, getChoiceIds(model.authoring.correct));
      updateResponseRules(model);
    };
  },

  removeChoiceAndUpdateRules(id: string) {
    return (model: CATA, post: PostUndoable) => {
      post(
        makeUndoable('Removed choice', [
          Operations.replace('$.authoring', clone(model.authoring)),
          Operations.replace('$.choices', clone(model.choices)),
        ]),
      );

      ChoiceActions.removeChoice(id)(model, post);

      remove(id, getChoiceIds(model.authoring.correct));
      model.authoring.targeted.forEach((assoc: any) => remove(id, getChoiceIds(assoc)));

      updateResponseRules(model);
    };
  },

  addTargetedFeedback(choicesPath = CHOICES_PATH) {
    return (model: CATA) => {
      const choiceIds = getChoices(model, choicesPath).map((c) => c.id);
      const response = makeResponse(matchListRule(choiceIds, []), 0, '');

      ResponseActions.addResponse(response, DEFAULT_PART_ID)(model);
      model.authoring.targeted.push([[], response.id]);
    };
  },

  editTargetedFeedbackChoices(responseId: ResponseId, choiceIds: ChoiceId[]) {
    return (model: CATA) => {
      const assoc = model.authoring.targeted.find(
        (assoc: any) => getResponseId(assoc) === responseId,
      );
      if (!assoc) return;
      assoc[0] = choiceIds;
      updateResponseRules(model);
    };
  },
};

// Update all response rules based on a model with new choices that
// are not yet reflected by the rules.
const updateResponseRules = (model: CATA) => {
  getCorrectResponse(model, DEFAULT_PART_ID).rule = matchListRule(
    model.choices.map((c: any) => c.id),
    getCorrectChoiceIds(model),
  );

  model.authoring.targeted.forEach((assoc) => {
    getResponseBy(model, (r) => r.id === getResponseId(assoc)).rule = matchListRule(
      model.choices.map((c: any) => c.id),
      getChoiceIds(assoc),
    );
  });
};
