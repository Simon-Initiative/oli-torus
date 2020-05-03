
import { ActivityModelSchema } from '../types';
import { ModelElement, Identifiable } from 'data/content/model';

export type RichText = ModelElement[];

interface HasContent {
  content: RichText;
}

export interface Stem extends HasContent {}
export interface Choice extends Identifiable, HasContent {}
export interface Hint extends Identifiable, HasContent {}
export interface Feedback extends Identifiable, HasContent {
  // `match` corresponds to Choice::id. Later, it can be used
  // for a catch-all and non 1:1 choice:feedback mappings
  match: string | number;
  // `score == 1` indicates the feedback corresponds to a matching choice
  score: number;
}

export interface MultipleChoiceModelSchema extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    feedback: Feedback[];
    hints: Hint[];
  };
}

export interface ModelEditorProps {
  model: MultipleChoiceModelSchema;
  editMode: boolean;
}
