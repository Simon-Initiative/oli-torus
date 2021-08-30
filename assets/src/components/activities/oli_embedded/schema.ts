import {ActivityModelSchema, Part, Stem} from '../types';

export interface OliEmbeddedModelSchema extends ActivityModelSchema {
  stem: Stem;
  title: string;
  authoring: {
    parts: Part[];
    previewText: string;
  };
}

