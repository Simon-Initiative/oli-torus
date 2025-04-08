import { ActivityModelSchema } from '../types';

export interface LTIExternalToolSchema extends ActivityModelSchema {
  clientId?: string;
  authoring: {
    openInNewTab: boolean;
  };
}
