import { MCSchemaV1 } from 'components/activities/multiple_choice/transformations/v1';
import {
  ActivityModelSchema,
  Choice,
  ChoiceIdsToResponseId,
  Part,
  Stem,
  Transformation,
} from 'components/activities/types';
import { Responses, getCorrectResponse, getResponses } from 'data/activities/model/responses';
import { matchRule } from 'data/activities/model/rules';

export interface MCSchemaV2 extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    version: 2;
    targeted: ChoiceIdsToResponseId[];
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}

export const mcV1toV2 = (model: MCSchemaV1): MCSchemaV2 => {
  const newModel: MCSchemaV2 = {
    stem: model.stem,
    choices: model.choices,
    authoring: {
      version: 2,
      parts: model.authoring.parts,
      transformations: model.authoring.transformations,
      previewText: model.authoring.previewText,
      targeted: [],
    },
  };

  if (!getResponses(newModel).find((r) => r.rule === matchRule('.*'))) {
    newModel.authoring.parts[0].responses = [
      getCorrectResponse(newModel, model.authoring.parts[0].id),
      Responses.catchAll(),
    ];
  }

  return newModel;
};
