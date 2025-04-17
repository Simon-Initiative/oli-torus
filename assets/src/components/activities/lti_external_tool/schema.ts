import { ActivityModelSchema, Part } from '../types';

export interface LTIExternalToolSchema extends ActivityModelSchema {
  openInNewTab: boolean;
  authoring: {
    parts: Part[];
  };
}
