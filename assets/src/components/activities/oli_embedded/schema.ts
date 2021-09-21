import {ActivityModelSchema, Part, Stem} from '../types';

export interface OliEmbeddedModelSchema extends ActivityModelSchema {
  baseUrl: string;
  modelXml: string;
  resourceUrls: string[];
  stem: Stem;
  title: string;
  authoring: {
    parts: Part[];
    previewText: string;
  };
}

