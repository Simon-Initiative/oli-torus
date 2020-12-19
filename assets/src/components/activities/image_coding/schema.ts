
import { ActivityModelSchema, Stem, Hint, Part } from '../types';

export interface ImageCodingModelSchema extends ActivityModelSchema {
  stem: Stem;
  isExample: boolean;
  starterCode: string;
  solutionCode: string;
  // for evaluation:
  tolerance: number;
  regex: string;
  authoring: {
    parts: Part[];
    previewText: string;
  };
}

export interface ModelEditorProps {
  model: ImageCodingModelSchema;
  editMode: boolean;
}
