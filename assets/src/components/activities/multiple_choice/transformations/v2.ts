import {
  ActivityModelSchema,
  Choice,
  ChoiceIdsToResponseId,
  makeResponse,
  Part,
  Stem,
  Transformation,
} from 'components/activities/types';
import { getCorrectResponse, getResponses } from 'data/activities/model/responseUtils';
import { matchRule } from 'data/activities/model/rules';
import { MCSchemaV1 } from 'components/activities/multiple_choice/transformations/v1';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';

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
      getCorrectResponse(newModel, DEFAULT_PART_ID),
      makeResponse(matchRule('.*'), 0, ''),
    ];
  }

  return newModel;
};
