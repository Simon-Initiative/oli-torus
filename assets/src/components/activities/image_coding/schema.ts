
import { ActivityModelSchema, Stem, Part, Feedback } from '../types';

export interface ImageCodingModelSchema extends ActivityModelSchema {
  stem: Stem;
  isExample: boolean;
  starterCode: string;
  solutionCode: string;
  resourceURLs: string[];
  // for evaluation:
  tolerance: number;
  regex: string;
  feedback: Feedback[];
  authoring: {
    parts: Part[];
    previewText: string;
  };
}

export interface ModelEditorProps {
  model: ImageCodingModelSchema;
  editMode: boolean;
}
