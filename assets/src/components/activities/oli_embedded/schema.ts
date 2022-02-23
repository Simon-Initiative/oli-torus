import { ActivityModelSchema, Part, Stem } from '../types';

export interface OliEmbeddedModelSchema extends ActivityModelSchema {
  base: string;
  src: string;
  modelXml: string;
  resourceBase: string;
  resourceURLs: string[];
  stem: Stem;
  title: string;
  authoring: {
    parts: Part[];
    previewText: string;
  };
}
