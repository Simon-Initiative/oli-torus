
import { HasContent, Part, Transformation, ActivityModelSchema } from '../types';
import { Identifiable } from 'data/content/model';

export interface Stem extends HasContent {}
export interface Choice extends Identifiable, HasContent {}

export interface MultipleChoiceModelSchema extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    parts: Part[];
    transformations: Transformation[];
  };
}

export interface ModelEditorProps {
  model: MultipleChoiceModelSchema;
  editMode: boolean;
}
