
import { Part, Transformation, ActivityModelSchema } from '../types';

export interface AdaptiveModelSchema extends ActivityModelSchema {
  // eslint-disable-next-line
  content: Object;
  authoring: {
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}

export interface ModelEditorProps {
  model: AdaptiveModelSchema;
  editMode: boolean;
}
