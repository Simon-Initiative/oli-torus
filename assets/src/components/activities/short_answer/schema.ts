import { ActivityModelSchema, Part, Stem, Transformation } from '../types';

export type InputType = 'text' | 'numeric' | 'textarea' | 'math' | 'vlabvalue';
export const isInputType = (s: string): s is InputType =>
  ['text', 'numeric', 'textarea', 'math', 'vlabvalue'].includes(s);

export interface ShortAnswerModelSchema extends ActivityModelSchema {
  stem: Stem;
  inputType: InputType;
  submitAndCompare?: boolean;
  authoring: {
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
  responses?: { user_name: string; text: string }[];
}
