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

export type VlabInput = Dropdown | FillInTheBlank | VlabValue;
export type VlabInputDelivery =
  | { id: string; inputType: 'dropdown'; options: SelectOption[] }
  | { id: string; inputType: 'text' | 'numeric' | 'vlabvalue' };

export interface Dropdown extends Identifiable {
  inputType: 'dropdown';
  partId: string;
  choiceIds: ChoiceId[];
}
export interface FillInTheBlank extends Identifiable {
  inputType: 'text' | 'numeric';
  partId: string;
}

export interface VlabValue extends Identifiable {
  inputType: 'numeric';
  partId: string;
  species?: string;
  parameter: string;
}

export type VlabInputType = 'dropdown' | 'text' | 'numeric' | 'vlabvalue';
export const vlabInputTypes: VlabInputType[] = ['dropdown', 'text', 'numeric', 'vlabvalue'];

export const VlabInputTypeFriendly = (type: VlabInputType): string =>
  Maybe.maybe(
    {
      dropdown: 'Dropdown',
      numeric: 'Number',
      text: 'Text',
      vlabvalue: 'Vlab Value',
    }[type],
  ).valueOr(assertNever(type));

export type VlabParameter = 'volume' | 'temp';

export interface VlabSchema extends ActivityModelSchema {
  stem: Stem;
  // This is a separated out rather than putting a dropdown's choices under
  // its item in the `inputs` array because the backend transformation logic
  // take a string key to shuffle, and doesn't allow for predicate logic.
  choices: Choice[];
  // The actual student-answerable inputs, designated by their type
  inputs: VlabInput[];
  authoring: {
    targeted: ChoiceIdsToResponseId[];
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}
