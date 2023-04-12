import {
  ActivityModelSchema,
  Choice,
  ChoiceIdsToResponseId,
  Part,
  RichText,
  Stem,
  Transformation,
  makeChoice,
  makeStem,
} from '../types';
import { ID } from 'data/content/model/other';
import { Maybe } from 'tsmonad';

// Likert Scale element. Functions as subclass of Choice
export class LikertChoice implements Choice {
  id: ID;
  content: RichText;
  // set only if using non-default value:
  value: Maybe<number>;
}

export const makeLikertChoice: (s: string) => LikertChoice = (text) => {
  const choice: any = makeChoice(text);
  choice.value = Maybe.nothing();
  return choice;
};

// Individual item in a multi-part Likert is like question stem
export class LikertItem implements Stem {
  id: ID;
  content: RichText;
  // optional group id:
  group: Maybe<string> = Maybe.nothing();
  required = false;
}

export const makeLikertItem: (s: string) => LikertItem = (text) => {
  const item: any = makeStem(text);
  item.group = Maybe.nothing;
  item.required = false;
  return item;
};

export interface LikertModelSchema extends ActivityModelSchema {
  stem: Stem;
  choices: LikertChoice[];
  orderDescending: boolean;
  items: LikertItem[];
  authoring: {
    targeted: ChoiceIdsToResponseId[];
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}

export interface ModelEditorProps {
  model: LikertModelSchema;
  editMode: boolean;
}
