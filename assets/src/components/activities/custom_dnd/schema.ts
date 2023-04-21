import { ActivityModelSchema, Part, Stem, Transformation } from '../types';

export interface CustomDnDSchema extends ActivityModelSchema {
  stem: Stem;
  height: string;
  width: string;
  layoutStyles: string;
  targetArea: string;
  initiators: string;
  authoring: {
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}
