import { ActivityEditContext } from 'data/content/activity';
import { ActivityReference, ResourceContent } from 'data/content/resource';
import { ProjectSlug } from 'data/types';

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

export type DragPayload = ResourceContent | ActivityPayload | UnknownPayload;
