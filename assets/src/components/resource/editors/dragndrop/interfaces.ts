import { Activity, ActivityReference, StructuredContent } from 'data/content/resource';
import { ProjectSlug } from 'data/types';

export interface ActivityPayload {
  type: 'ActivityPayload';
  id: string;
  activity: Activity;
  reference: ActivityReference;
  project: ProjectSlug;
}

export interface UnknownPayload {
  type: 'UnknownPayload';
  id: string;
  data: any;
}

export type DragPayload = StructuredContent | ActivityPayload | UnknownPayload;
