
import { HasContent, Part, Transformation, ActivityModelSchema, Stem } from '../types';
import { Identifiable } from 'data/content/model';

export interface ShortAnswerModelSchema extends ActivityModelSchema {
  stem: Stem;
  authoring: {
    parts: Part[];
    transformations: Transformation[];
  };
}

export interface ModelEditorProps {
  model: ShortAnswerModelSchema;
  editMode: boolean;
}
