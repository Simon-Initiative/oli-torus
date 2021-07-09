import {
  ActivityModelSchema,
  Choice,
  ChoiceIdsToResponseId,
  Part,
  Stem,
  Transformation,
} from 'components/activities/types';

export type OrderingSchemaV1 = SimpleOrdering | TargetedOrdering;

interface BaseOrdering extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    // An association list of the choice ids in the correct order to the matching response id
    correct: ChoiceIdsToResponseId;
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}

type SimpleOrdering = BaseOrdering & {
  type: 'SimpleOrdering';
};

type TargetedOrdering = BaseOrdering & {
  type: 'TargetedOrdering';
  authoring: {
    // An association list of choice id orderings to matching targeted response ids
    targeted: ChoiceIdsToResponseId[];
  };
};
