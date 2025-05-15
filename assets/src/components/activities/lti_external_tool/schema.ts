import { ActivityModelSchema, Part } from '../types';

export interface LTIExternalToolSchema extends ActivityModelSchema {
  openInNewTab: boolean;
  height?: number;
  authoring: {
    parts: Part[];
  };
}
