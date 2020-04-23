import { ModelElement } from './model';
import { ProjectSlug, ResourceSlug, ObjectiveSlug, ActivitySlug, ActivityTypeSlug } from 'data/types';
import { Objective } from 'data/content/objective';

import guid from 'utils/guid';
import { ActivityModelSchema } from 'components/activities/types';

// The types of things that can be present as top level
// entries in a resource content array
export type ResourceContent = StructuredContent | ActivityReference;

// The full context necessary to operate a resource editing session
export type ResourceContext = {
  graded: boolean,                // Page or assessment?
  authorEmail: string,            // The current author
  projectSlug: ProjectSlug,       // The current project
  resourceSlug: ResourceSlug,     // The current resource
  title: string,                  // The title of the resource
  content: ResourceContent[],     // Content of the resource
  objectives: ObjectiveSlug[],    // Attached objectives
  allObjectives: Objective[],     // All objectives
};

export enum ResourceType {
  'page',
  'assessment',
}

export enum ContentPurpose {
  'none' = 'None',
  'example' = 'Example',
  'learnmore' = 'Learn more',
}

export enum ActivityPurpose {
  'none' = 'None',
  'learnbydoing' = 'Learn by doing',
  'didigetthis' = 'Did I get this?',
  'lab' = 'Lab',
  'manystudentswonder' = 'Many students wonder',
  'simulation' = 'Simulation',
  'walkthrough' = 'Walkthrough',
}

export const createDefaultStructuredContent = () => {
  return {
    type: 'content',
    id: guid(),
    children: [
      { type: 'p', id: guid(), children: [{ text: ' ' }] },
    ],
    purpose: ContentPurpose.none,
  } as StructuredContent;
};

export interface StructuredContent {
  type: 'content';
  id: number;
  children: ModelElement[];
  purpose: ContentPurpose;
}

export interface ActivityReference {
  type: 'activity-reference';
  id: number;
  activitySlug: ActivitySlug;
  purpose: ActivityPurpose;
  children: [];
}

export interface Activity {
  type: 'activity';
  activitySlug: ActivitySlug;
  typeSlug: ActivityTypeSlug;
  model: ActivityModelSchema;
}

export interface ActivityMap {
  [prop: string]: Activity;
}
