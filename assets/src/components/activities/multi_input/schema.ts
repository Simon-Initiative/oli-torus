import { MultiInput } from 'components/activities/multi_input/utils';
import {
  Stem,
  ActivityModelSchema,
  ChoiceIdsToResponseId,
  Part,
  Transformation,
  Choice,
} from 'components/activities/types';
import { ID } from 'data/content/model';

type DropdownChoices = [ID, Choice];

export interface MultiInputSchema extends ActivityModelSchema {
  // Has one more stem than the number of parts/inputs.
  // Stems are interspersed with parts when rendered
  stems: Stem[];
  // An association list of [partId, Choice].
  // This is a separated out rather than putting a dropdown's choices under
  // its item in the `inputs` array because the backend transformation logic
  // take a string key to shuffle, and doesn't allow for predicate logic.
  choices: DropdownChoices[];
  // The actual student-answerable inputs, designated by their type
  inputs: MultiInput[];
  authoring: {
    targeted: ChoiceIdsToResponseId[];
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}
