
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
  // Score indicates whether the feedback corresponds to a correct
  // or incorrect answer. `score == 1` indicates the feedback / matching
  // choice are correct
  score: number;
}

// Separate this out into separate schemas for authoring and delivery with `authoring` key?
export interface MultipleChoiceModelSchema extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    feedback: Feedback[];
    hints: Hint[];
  };
}

// authoring component -> access through authoring key to get
// feedback/hints, update puts them back into authoring key

// const model = Object.entries(parsed).reduce((acc: any, [key, value]: [string, any]) => {
//   if (key === 'authoring') return acc;
//   acc[key] = value;
//   return acc;
// }, {});



// what should it do if a question has no parts?
// how to specify the parts of the activity
