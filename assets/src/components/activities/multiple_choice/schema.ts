
import { HasContent, Part, Transformation, ActivityModelSchema, Stem } from '../types';
import { Identifiable } from 'data/content/model';

export interface Choice extends Identifiable, HasContent {}

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
