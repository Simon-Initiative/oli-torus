import { ModelElement, Selection } from './model';
import { ProjectSlug, ResourceSlug, ObjectiveSlug, ActivitySlug, ActivityTypeSlug } from 'data/types';
import { Objective } from 'data/content/objective';

import guid from 'utils/guid';
import { ActivityModelSchema } from 'components/activities/types';


export type PageContent = {
  model: ResourceContent[],
};

export type AttachedObjectives = {
  attached: ObjectiveSlug[],
};

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
  content: PageContent,           // Content of the resource
  objectives: AttachedObjectives, // Attached objectives
  allObjectives: Objective[],     // All objectives
};

export enum ResourceType {
  'page',
  'assessment',
}

export type Purpose = {
  value: string,
  label: string,
};

export const ActivityPurposes: Purpose[] = [
  { value: 'none', label: 'None' },
  { value: 'checkpoint', label: 'Checkpoint' },
  { value: 'didigetthis', label: 'Did I get this?' },
  { value: 'learnbydoing', label: 'Learn by doing' },
  { value: 'manystudentswonder', label: 'Many students wonder' },
];

export const ContentPurposes: Purpose[] = [
  { value: 'none', label: 'None' },
  { value: 'example', label: 'Example' },
  { value: 'learnmore', label: 'Learn more' },
];




export const createDefaultStructuredContent = () => {
  return {
    type: 'content',
    id: guid(),
    children: [
      { type: 'p', id: guid(), children: [{ text: '' }] },
    ],
    purpose: 'none',
    selection: null,
  } as StructuredContent;
};

export interface StructuredContent {
  type: 'content';
  id: string;
  children: ModelElement[];
  purpose: string;
  selection: Selection;
}

export interface ActivityReference {
  type: 'activity-reference';
  id: string;
  activitySlug: ActivitySlug;
  purpose: string;
  children: [];
}

export interface Activity {
  type: 'activity';
  activitySlug: ActivitySlug;
  typeSlug: ActivityTypeSlug;
  model: ActivityModelSchema;
  transformed: ActivityModelSchema | null;
}

export interface ActivityMap {
  [prop: string]: Activity;
}
