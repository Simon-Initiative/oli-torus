import {
  ActivityLevelScoring,
  ActivityModelSchema,
  Choice,
  ChoiceIdsToResponseId,
  Part,
  Stem,
  Transformation,
} from 'components/activities/types';
import { MultiInput } from '../multi_input/schema';

export interface ResponseMultiInputSchema extends ActivityModelSchema, ActivityLevelScoring {
  stem: Stem;
  // This is a separated out rather than putting a dropdown's choices under
  // its item in the `inputs` array because the backend transformation logic
  // take a string key to shuffle, and doesn't allow for predicate logic.
  choices: Choice[];
  // The actual student-answerable inputs, designated by their type
  inputs: MultiInput[];
  submitPerPart: boolean;
  multInputsPerPart: boolean;
  authoring: {
    targeted: ChoiceIdsToResponseId[];
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
    responses?: { user_name: string; text: string }[];
  };
}
