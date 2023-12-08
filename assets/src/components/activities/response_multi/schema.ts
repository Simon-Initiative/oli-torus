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

export type ResponseMultiInputSize = 'small' | 'medium' | 'large' | '100pct';

export type ResponseMultiInput = Dropdown | FillInTheBlank;
export type ResponseMultiInputDelivery =
  | { id: string; inputType: 'dropdown'; options: SelectOption[]; size?: ResponseMultiInputSize }
  | { id: string; inputType: 'text' | 'numeric' | 'math'; size?: ResponseMultiInputSize };

export interface Dropdown extends Identifiable {
  inputType: 'dropdown';
  partId: string;
  choiceIds: ChoiceId[];
  size?: ResponseMultiInputSize;
}

export interface FillInTheBlank extends Identifiable {
  inputType: 'text' | 'numeric' | 'math';
  partId: string;
  size?: ResponseMultiInputSize;
}

export type ResponseMultiInputType = 'dropdown' | 'text' | 'numeric' | 'math';
export const multiInputTypes: ResponseMultiInputType[] = ['dropdown', 'text', 'numeric', 'math'];

export const multiInputTypeFriendly = (type: ResponseMultiInputType): string =>
  Maybe.maybe(
    {
      dropdown: 'Dropdown',
      numeric: 'Number',
      text: 'Text',
      math: 'Math',
    }[type],
  ).valueOr(assertNever(type));

export interface ResponseMultiInputSchema extends ActivityModelSchema, ActivityLevelScoring {
  stem: Stem;
  // This is a separated out rather than putting a dropdown's choices under
  // its item in the `inputs` array because the backend transformation logic
  // take a string key to shuffle, and doesn't allow for predicate logic.
  choices: Choice[];
  // The actual student-answerable inputs, designated by their type
  inputs: ResponseMultiInput[];
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
