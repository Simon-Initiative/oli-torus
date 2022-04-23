import { ActivityModelSchema, Part, PartComponentDefinition, Transformation } from '../types';

export interface AdaptiveModelSchema extends ActivityModelSchema {
  content?: {
    custom?: Record<string, any>;
    partsLayout?: PartComponentDefinition[];
  };
  custom?: Record<string, any>;
  partsLayout?: PartComponentDefinition[];
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
