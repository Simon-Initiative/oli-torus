import { ActivityModelSchema, Part } from '../types';

export interface LTIDeepLinkSelection {
  type: 'ltiResourceLink';
  url?: string;
  custom?: Record<string, unknown>;
  title?: string;
  text?: string;
}

export interface LTIExternalToolSchema extends ActivityModelSchema {
  openInNewTab: boolean;
  deepLink?: LTIDeepLinkSelection;
  height?: number;
  authoring: {
    parts: Part[];
  };
}
