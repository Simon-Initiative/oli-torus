import * as Immutable from 'immutable';
import { ActivityModelSchema } from 'components/activities/types';
import * as Bank from 'data/content/bank';
import { Model } from 'data/content/model/elements/factories';
import { ModelElement } from 'data/content/model/elements/types';
import { Objective } from 'data/content/objective';
import { Tag } from 'data/content/tags';
import { ActivitySlug, ActivityTypeSlug, ProjectSlug, ResourceId, ResourceSlug } from 'data/types';
import guid from 'utils/guid';
import { ActivityEditContext } from './activity';

export type PageContent = {
  model: ResourceContent[];
  [key: string]: any;
};

export type AttachedObjectives = {
  attached: ResourceId[];
};

// The types of things that can be present as top level
// entries in a resource content array
export type ResourceContent =
  | GroupContent
  | StructuredContent
  | ActivityReference
  | ActivityBankSelection;

export const getResourceContentName = (content: ResourceContent) => {
  switch (content.type) {
    case 'activity-reference':
      return 'Activity';
    case 'content':
      return 'Content';
    case 'group':
      return 'Group';
    case 'selection':
      return 'Selection';
  }
};

// The full context necessary to operate a resource editing session
export type ResourceContext = {
  graded: boolean; // Page or assessment?
  authorEmail: string; // The current author
  projectSlug: ProjectSlug; // The current project
  resourceSlug: ResourceSlug; // The current resource
  resourceId: ResourceId; // The resource id
  title: string; // The title of the resource
  content: PageContent; // Content of the resource
  objectives: AttachedObjectives; // Attached objectives
  allObjectives: Objective[]; // All objectives
  allTags: Tag[]; // All available tags
  activityContexts: ActivityEditContext[]; // Contexts for inline activity editing
};

export enum ResourceType {
  'page',
  'assessment',
}

export type Purpose = {
  value: string;
  label: string;
};

export const PurposeTypes: Purpose[] = [
  { value: 'none', label: 'None' },
  { value: 'checkpoint', label: 'Checkpoint' },
  { value: 'didigetthis', label: 'Did I get this?' },
  { value: 'example', label: 'Example' },
  { value: 'labactivity', label: 'Lab' },
  { value: 'learnbydoing', label: 'Learn by doing' },
  { value: 'learnmore', label: 'Learn more' },
  { value: 'manystudentswonder', label: 'Many students wonder' },
  { value: 'quiz', label: 'Quiz' },
  { value: 'simulation', label: 'Simulation' },
  { value: 'walkthrough', label: 'Walkthrough' },
];

export const createDefaultStructuredContent = (
  children: ModelElement[] = [Model.p()],
): StructuredContent => ({
  type: 'content',
  id: guid(),
  children,
  purpose: 'none',
});

export const createGroup = (
  children: Immutable.List<ResourceContent> = Immutable.List([createDefaultStructuredContent()]),
): GroupContent => ({
  type: 'group',
  id: guid(),
  children,
  layout: 'vertical',
  purpose: 'none',
});

export const createDefaultSelection = () => {
  return {
    type: 'selection',
    id: guid(),
    count: 1,
    logic: { conditions: null },
    purpose: 'none',
  } as ActivityBankSelection;
};

export interface StructuredContent {
  type: 'content';
  id: string;
  children: ModelElement[];
  purpose: string;
}

export interface ActivityBankSelection {
  type: 'selection';
  id: string;
  logic: Bank.Logic;
  count: number;
  purpose: string;
  children: undefined;
}

export interface ActivityReference {
  type: 'activity-reference';
  id: string;
  activitySlug: ActivitySlug;
  purpose: string;
  children: [];
}

export interface GroupContent {
  id: string;
  type: 'group';
  layout: string; // TODO define layout types
  purpose: string;
  children: Immutable.List<ResourceContent>;
}

export interface Activity {
  type: 'activity';
  activitySlug: ActivitySlug;
  typeSlug: ActivityTypeSlug;
  model: ActivityModelSchema;
  transformed: ActivityModelSchema | null;
  // eslint-disable-next-line
  objectives: Object;
}

export interface ActivityMap {
  [prop: string]: Activity;
}
