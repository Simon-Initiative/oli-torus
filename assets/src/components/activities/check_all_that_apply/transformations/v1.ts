import {
  ActivityModelSchema,
  Choice,
  ChoiceIdsToResponseId,
  Part,
  Stem,
  Transformation,
} from 'components/activities/types';

export type CATASchemaV1 = SimpleCATA | TargetedCATA;

interface BaseCATA extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    // An association list of correct choice ids to the matching response id
    correct: ChoiceIdsToResponseId;
    // An association list of incorrect choice ids to the matching response id
    incorrect: ChoiceIdsToResponseId;
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}

type SimpleCATA = BaseCATA & {
  type: 'SimpleCATA';
};

type TargetedCATA = BaseCATA & {
  type: 'TargetedCATA';
  authoring: {
    // An association list of choice ids to the matching targeted response id
    targeted: ChoiceIdsToResponseId[];
  };
};
