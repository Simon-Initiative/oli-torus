import {
  ActivityModelSchema,
  Choice,
  ChoiceIdsToResponseId,
  makeResponse,
  Part,
  Stem,
  Transformation,
} from 'components/activities/types';
import { OrderingSchemaV1 as V1 } from 'components/activities/ordering/transformations/v1';
import { Maybe } from 'tsmonad';
import {
  getChoiceIds,
  getCorrectResponse,
  getResponseBy,
  getResponseId,
  getResponses,
  getTargetedResponses,
} from 'data/activities/model/responseUtils';
import { matchInOrderRule, matchRule } from 'data/activities/model/rules';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';

export interface OrderingSchemaV2 extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    version: 2;
    // An association list of the choice ids in the correct order to the matching response id
    correct: ChoiceIdsToResponseId;
    targeted: ChoiceIdsToResponseId[];
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}

export const orderingV1toV2 = (model: V1): OrderingSchemaV2 => {
  const newModel: OrderingSchemaV2 = {
    stem: model.stem,
    choices: model.choices,
    authoring: {
      version: 2,
      correct: model.authoring.correct,
      parts: model.authoring.parts,
      transformations: model.authoring.transformations,
      previewText: model.authoring.previewText,
      targeted: model.type === 'SimpleOrdering' ? [] : model.authoring.targeted,
    },
  };

  if (getChoiceIds(newModel.authoring.correct).length !== newModel.choices.length) {
    newModel.authoring.correct[0] = newModel.choices.map((c) => c.id);
    getCorrectResponse(newModel, DEFAULT_PART_ID).rule = matchInOrderRule(
      newModel.authoring.correct[0],
    );
  }

  if (newModel.authoring.targeted.length > 0) {
    newModel.authoring.targeted.forEach((assoc) => {
      const choiceIds = getChoiceIds(assoc);
      if (choiceIds.length !== newModel.choices.length) {
        assoc[0] = newModel.choices.map((c) => c.id);
        getResponseBy(newModel, (r) => r.id === getResponseId(assoc)).rule =
          matchInOrderRule(choiceIds);
      }
    });
  }

  Maybe.maybe(
    getResponses(newModel).find(
      (response) =>
        response !== getCorrectResponse(newModel, DEFAULT_PART_ID) &&
        !getTargetedResponses(newModel).includes(response),
    ),
  ).caseOf({
    just: (incorrectResponse) => void (incorrectResponse.rule = matchRule('.*')),
    nothing: () =>
      void newModel.authoring.parts[0].responses.push(makeResponse(matchRule('.*'), 0, '')),
  });

  return newModel;
};
