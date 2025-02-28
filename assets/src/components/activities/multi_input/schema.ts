import { Maybe } from 'tsmonad';
import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import {
  ActivityLevelScoring,
  ActivityModelSchema,
  Choice,
  ChoiceId,
  ChoiceIdsToResponseId,
  Part,
  Stem,
  Transformation,
} from 'components/activities/types';
import { Identifiable } from 'data/content/model/other';
import { assertNever } from 'utils/common';

export type MultiInputSize = 'small' | 'medium' | 'large' | '100pct';

export type MultiInput = Dropdown | FillInTheBlank;
export type MultiInputDelivery =
  | { id: string; inputType: 'dropdown'; options: SelectOption[]; size?: MultiInputSize }
  | { id: string; inputType: 'text' | 'numeric' | 'math'; size?: MultiInputSize };

export interface Dropdown extends Identifiable {
  inputType: 'dropdown';
  partId: string;
  choiceIds: ChoiceId[];
  size?: MultiInputSize;
}

export interface FillInTheBlank extends Identifiable {
  inputType: 'text' | 'numeric' | 'math';
  partId: string;
  size?: MultiInputSize;
}

export type MultiInputType = 'dropdown' | 'text' | 'numeric' | 'math';
export const multiInputTypes: MultiInputType[] = ['dropdown', 'text', 'numeric', 'math'];

export const multiInputTypeFriendly = (type: MultiInputType): string =>
  Maybe.maybe(
    {
      dropdown: 'Dropdown',
      numeric: 'Number',
      text: 'Text',
      math: 'Math',
    }[type],
  ).valueOr(assertNever(type));

export interface MultiInputSchema extends ActivityModelSchema, ActivityLevelScoring {
  stem: Stem;
  // This is a separated out rather than putting a dropdown's choices under
  // its item in the `inputs` array because the backend transformation logic
  // take a string key to shuffle, and doesn't allow for predicate logic.
  choices: Choice[];
  // The actual student-answerable inputs, designated by their type
  inputs: MultiInput[];
  submitPerPart: boolean;
  authoring: {
    targeted: ChoiceIdsToResponseId[];
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
    responses?: { users: string[]; text: string; type: string; part_id: string; count: number }[];
  };
}
