import { Part, Transformation, ActivityModelSchema, Stem } from '../types';

export interface CustomDnDSchema extends ActivityModelSchema {
  stem: Stem;
  layoutStyles: string;
  targetArea: string;
  initiators: string;
  authoring: {
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}
