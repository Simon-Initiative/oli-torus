import {
  ActivityModelSchema,
  Choice,
  Part,
  Stem,
  Transformation,
} from 'components/activities/types';

export interface MCSchemaV1 extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}
