import { ActivityModelSchema, Part, Stem, Transformation } from '../types';

export interface FileSpec {
  accept: string;
  maxCount: number;
  maxSizeInBytes?: number;
}

export interface FileUploadSchema extends ActivityModelSchema {
  stem: Stem;
  fileSpec: FileSpec;
  authoring: {
    parts: Part[];
    transformations: Transformation[];
    previewText: string;
  };
}
