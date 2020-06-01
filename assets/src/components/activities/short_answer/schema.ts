
import { Part, Transformation, ActivityModelSchema, Stem } from '../types';

export type InputType = 'text' | 'numeric' | 'textarea';

export interface ShortAnswerModelSchema extends ActivityModelSchema {
  stem: Stem;
  inputType: InputType;
  authoring: {
    parts: Part[];
    transformations: Transformation[];
  };
}

export interface ModelEditorProps {
  model: ShortAnswerModelSchema;
  editMode: boolean;
}
