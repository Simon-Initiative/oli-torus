import { Maybe } from 'tsmonad';
import { TextDirection } from 'data/content/model/elements/types';
import { ID } from 'data/content/model/other';
import {
  ActivityModelSchema,
  Choice,
  ChoiceIdsToResponseId,
  Part,
  RichText,
  SpecifiesTextDirection,
  Stem,
  Transformation,
  makeChoice,
  makeStem,
} from '../types';

// Likert Scale element. Functions as subclass of Choice
export class LikertChoice implements Choice, SpecifiesTextDirection {
  id: ID;
  content: RichText;
  textDirection?: TextDirection;
  // set only if using non-default value:
  value: Maybe<number>;
  frequency: number;
}

export const makeLikertChoice: (s: string) => LikertChoice = (text) => {
  const choice: any = makeChoice(text);
  choice.value = Maybe.nothing();
  return choice;
};

// Individual item in a multi-part Likert is like question stem
export class LikertItem implements Stem, SpecifiesTextDirection {
  id: ID;
  content: RichText;
  textDirection?: TextDirection;
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
  activityTitle: string;
}

export interface ModelEditorProps {
  model: LikertModelSchema;
  editMode: boolean;
}
