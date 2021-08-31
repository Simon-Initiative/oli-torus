import { MultiInput } from 'components/activities/multi_input/utils';
import {
  Stem,
  ActivityModelSchema,
  ChoiceIdsToResponseId,
  Part,
  Transformation,
} from 'components/activities/types';

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
