
import { Part, Transformation, ActivityModelSchema, Stem, Choice } from '../types';

export interface MultipleChoiceModelSchema extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}

export interface ModelEditorProps {
  model: MultipleChoiceModelSchema;
  editMode: boolean;
}
