import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import {
  Stem,
  ActivityModelSchema,
  ChoiceIdsToResponseId,
  Part,
  Transformation,
  Choice,
  ChoiceId,
} from 'components/activities/types';
import { Identifiable } from 'data/content/model/other';
import { Maybe } from 'tsmonad';
import { assertNever } from 'utils/common';

export type MultiInput = Dropdown | FillInTheBlank;
export type MultiInputDelivery =
  | { id: string; inputType: 'dropdown'; options: SelectOption[] }
  | { id: string; inputType: 'text' | 'numeric' };

export interface Dropdown extends Identifiable {
  inputType: 'dropdown';
  partId: string;
  choiceIds: ChoiceId[];
}
export interface FillInTheBlank extends Identifiable {
  inputType: 'text' | 'numeric';
  partId: string;
}

export type MultiInputType = 'dropdown' | 'text' | 'numeric';
export const multiInputTypes: MultiInputType[] = ['dropdown', 'text', 'numeric'];

export const multiInputTypeFriendly = (type: MultiInputType): string =>
  Maybe.maybe(
    {
      dropdown: 'Dropdown',
      numeric: 'Number',
      text: 'Text',
    }[type],
  ).valueOr(assertNever(type));

export interface MultiInputSchema extends ActivityModelSchema {
  stem: Stem;
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
