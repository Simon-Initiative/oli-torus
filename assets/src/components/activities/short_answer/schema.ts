import { ItemConfig } from 'data/activities/model/match';
import { ActivityModelSchema, Part, Stem, Transformation } from '../types';

export type InputType = 'text' | 'numeric' | 'textarea' | 'math' | 'math_expression' | 'vlabvalue';
export const isInputType = (s: string): s is InputType =>
  ['text', 'numeric', 'textarea', 'math', 'math_expression', 'vlabvalue'].includes(s);

export interface ShortAnswerModelSchema extends ActivityModelSchema {
  stem: Stem;
  inputType: InputType;
  itemConfig?: ItemConfig;
  submitAndCompare?: boolean;
  authoring: {
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
  responses?: { users: string[]; text: string }[];
}
