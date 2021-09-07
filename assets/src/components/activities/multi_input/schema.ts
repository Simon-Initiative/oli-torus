import {
  Stem,
  ActivityModelSchema,
  ChoiceIdsToResponseId,
  Part,
  Transformation,
  Choice,
  ChoiceId,
} from 'components/activities/types';
// import { ID } from 'data/content/model';
import { assertNever } from 'utils/common';

// An association list of [partId, Choice] used for dropdown inputs
// type DropdownChoiceAssociation = { partId: ID; choice: Choice };

export type MultiInput = Dropdown | FillInTheBlank;

export type Dropdown = {
  type: 'dropdown';
  partId: string;
  choiceIds: ChoiceId[];
};
export type FillInTheBlank = {
  type: 'text' | 'numeric';
  partId: string;
};

export type MultiInputType = 'dropdown' | 'text' | 'numeric';
export const multiInputTypes: MultiInputType[] = ['dropdown', 'text', 'numeric'];

export const multiInputTypeFriendly = (type: MultiInputType): string => {
  switch (type) {
    case 'dropdown':
      return 'Dropdown';
    case 'numeric':
      return 'Number';
    case 'text':
      return 'Text';
    default:
      assertNever(type);
  }
};

export interface MultiInputSchema extends ActivityModelSchema {
  // Has one more stem than the number of parts/inputs.
  // Stems are interspersed with parts when rendered
  stems: Stem[];
  // This is a separated out rather than putting a dropdown's choices under
  // its item in the `inputs` array because the backend transformation logic
  // take a string key to shuffle, and doesn't allow for predicate logic.
  choices: Choice[];
  // The actual student-answerable inputs, designated by their type
  inputs: MultiInput[];
  authoring: {
    targeted: ChoiceIdsToResponseId[];
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}
