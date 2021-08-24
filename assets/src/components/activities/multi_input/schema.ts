import {
  Stem,
  ActivityModelSchema,
  ChoiceIdsToResponseId,
  Part,
  Transformation,
} from 'components/activities/types';

export type MultiInput = 'dropdown' | 'text' | 'numeric';
export interface MultiInputSchema extends ActivityModelSchema {
  // Has one more stem than the number of parts/inputs.
  // Stems are interspersed with parts when rendered
  stems: Stem[];
  // The actual student-answerable inputs, designated by their type
  inputs: MultiInput[];
  authoring: {
    targeted: ChoiceIdsToResponseId[];
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}
