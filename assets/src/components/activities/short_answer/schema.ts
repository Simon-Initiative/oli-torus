import { Part, Transformation, ActivityModelSchema, Stem } from '../types';

export type InputType = 'text' | 'numeric' | 'textarea';
export const isInputType = (s: string): s is InputType =>
  ['text', 'numeric', 'textarea'].includes(s);

export interface ShortAnswerModelSchema extends ActivityModelSchema {
  stem: Stem;
  inputType: InputType;
  authoring: {
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}
