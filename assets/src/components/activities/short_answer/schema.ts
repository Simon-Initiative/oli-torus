import { ActivityModelSchema, Part, Stem, Transformation } from '../types';

export type InputType = 'text' | 'numeric' | 'textarea' | 'math' | 'vlabvalue';
export const isInputType = (s: string): s is InputType =>
  ['text', 'numeric', 'textarea', 'math', 'vlabvalue'].includes(s);

export interface ShortAnswerModelSchema extends ActivityModelSchema {
  stem: Stem;
  inputType: InputType;
  authoring: {
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
  answers?: { user_name: string; response: string }[];
}
