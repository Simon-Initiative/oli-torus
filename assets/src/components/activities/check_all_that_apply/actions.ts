import {
  Choice,
  ChoiceId,
  ChoiceIdsToResponseId,
  Part,
  PostUndoable,
  ResponseId,
  makeResponse,
  makeUndoable,
} from '../types';
import { CATASchema as CATA } from './schema';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { addOrRemove, remove } from 'components/activities/common/utils';
import { Choices } from 'data/activities/model/choices';
import {
  getChoiceIds,
  getCorrectChoiceIds,
  getCorrectResponse,
  getResponseBy,
  getResponseId,
} from 'data/activities/model/responses';
import { matchListRule } from 'data/activities/model/rules';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';

// interface to use actions with other activity's models (ImageHotspot)
export interface CATACompatible {
  choices: Choice[];
  authoring: CATAAuthoring;
}

export interface CATAAuthoring {
  parts: Part[];
  correct: ChoiceIdsToResponseId;
  targeted: ChoiceIdsToResponseId[];
}

export const CATAActions = {
  addChoice(choice: Choice) {
    return (model: CATACompatible, post: PostUndoable) => {
      Choices.addOne(choice)(model);
      updateResponseRules(model);
    };
  },

  toggleChoiceCorrectness(choiceId: ChoiceId) {
    return (model: CATACompatible) => {
      addOrRemove(choiceId, getChoiceIds(model.authoring.correct));
      updateResponseRules(model);
    };
  },

  removeChoiceAndUpdateRules(id: string) {
    return (model: CATACompatible, post: PostUndoable) => {
      post(
        makeUndoable('Removed choice', [
          Operations.replace('$.authoring', clone(model.authoring)),
          Operations.replace('$.choices', clone(model.choices)),
        ]),
      );

      Choices.removeOne(id)(model);

      remove(id, getChoiceIds(model.authoring.correct));
      model.authoring.targeted.forEach((assoc: any) => remove(id, getChoiceIds(assoc)));

      updateResponseRules(model);
    };
  },

  addTargetedFeedback() {
    return (model: CATACompatible) => {
      const choiceIds = Choices.getAll(model).map((c) => c.id);
      const response = makeResponse(matchListRule(choiceIds, []), 0, '');

      ResponseActions.addResponse(response, model.authoring.parts[0].id)(model);
      model.authoring.targeted.push([[], response.id]);
    };
  },

  editTargetedFeedbackChoices(responseId: ResponseId, choiceIds: ChoiceId[]) {
    return (model: CATACompatible) => {
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
const updateResponseRules = (model: CATACompatible) => {
  getCorrectResponse(model, model.authoring.parts[0].id).rule = matchListRule(
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
