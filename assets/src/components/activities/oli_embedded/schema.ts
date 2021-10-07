import {ActivityModelSchema, Part, Stem} from '../types';

export interface OliEmbeddedModelSchema extends ActivityModelSchema {
  modelXml: string;
  resourceUrls: string[];
  stem: Stem;
  title: string;
  authoring: {
    parts: Part[];
    previewText: string;
  };
}

