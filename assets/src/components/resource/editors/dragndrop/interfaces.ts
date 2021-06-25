import { ActivityReference, StructuredContent } from 'data/content/resource';
import { ProjectSlug } from 'data/types';
import { ActivityEditContext } from 'data/content/activity';

export interface ActivityPayload {
  type: 'ActivityPayload';
  id: string;
  activity: ActivityEditContext;
  reference: ActivityReference;
  project: ProjectSlug;
}

export interface UnknownPayload {
  type: 'UnknownPayload';
  id: string;
  data: any;
}

export type DragPayload = StructuredContent | ActivityPayload | UnknownPayload;
