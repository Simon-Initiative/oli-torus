
import { HasContent, Part, Transformation, ActivityModelSchema, Stem } from '../types';
import { Identifiable } from 'data/content/model';

export interface Choice extends Identifiable, HasContent {}

export type CATACombination = Identifiable[];
export type CATACombinations = CATACombination[];

export interface CheckAllThatApplyModelSchema extends ActivityModelSchema {
  stem: Stem;
  choices: Choice[];
  authoring: {
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}

export interface ModelEditorProps {
  model: CheckAllThatApplyModelSchema;
  editMode: boolean;
}
