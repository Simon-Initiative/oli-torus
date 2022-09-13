import { CATASchemaV1 } from 'components/activities/check_all_that_apply/transformations/v1';
import {
  ActivityModelSchema,
  Choice,
  ChoiceIdsToResponseId,
  Part,
  Stem,
  Transformation,
} from 'components/activities/types';
import {
  getChoiceIds,
  getCorrectResponse,
  getResponseBy,
  getResponseId,
  getResponses,
  getTargetedResponses,
  Responses,
} from 'data/activities/model/responses';
import { matchListRule, matchRule } from 'data/activities/model/rules';
import { Maybe } from 'tsmonad';

// Support targeted feedback the way other activities do
export interface CATASchemaV2 extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    version: 2;
    // An association list of correct choice ids to the matching response id
    correct: ChoiceIdsToResponseId;
    targeted: ChoiceIdsToResponseId[];
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}

export const cataV1toV2 = (model: CATASchemaV1): CATASchemaV2 => {
  const newModel: CATASchemaV2 = {
    stem: model.stem,
    choices: model.choices,
    authoring: {
      version: 2,
      correct: model.authoring.correct,
      parts: model.authoring.parts,
      transformations: model.authoring.transformations,
      previewText: model.authoring.previewText,
      targeted: model.type === 'SimpleCATA' ? [] : model.authoring.targeted,
    },
  };

  if (getChoiceIds(newModel.authoring.correct).length !== newModel.choices.length) {
    newModel.authoring.correct[0] = newModel.choices.map((c) => c.id);
    getCorrectResponse(newModel, newModel.authoring.parts[0].id).rule = matchListRule(
      newModel.choices.map((c) => c.id),
      newModel.authoring.correct[0],
    );
  }

  if (newModel.authoring.targeted.length > 0) {
    newModel.authoring.targeted.forEach((assoc) => {
      const choiceIds = getChoiceIds(assoc);
      if (choiceIds.length !== newModel.choices.length) {
        assoc[0] = newModel.choices.map((c) => c.id);
        getResponseBy(newModel, (r) => r.id === getResponseId(assoc)).rule = matchListRule(
          newModel.choices.map((c) => c.id),
          choiceIds,
        );
      }
    });
  }

  Maybe.maybe(
    getResponses(newModel).find(
      (response) =>
        response !== getCorrectResponse(newModel, newModel.authoring.parts[0].id) &&
        !getTargetedResponses(newModel).includes(response),
    ),
  ).caseOf({
    just: (incorrectResponse) => void (incorrectResponse.rule = matchRule('.*')),
    nothing: () => void newModel.authoring.parts[0].responses.push(Responses.catchAll()),
  });

  return newModel;
};
