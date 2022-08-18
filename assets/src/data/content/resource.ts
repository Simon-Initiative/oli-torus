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
  bibrefs?: string[];
  [key: string]: any;
};

export type AttachedObjectives = {
  attached: ResourceId[];
};

// Items that can be present as elements in a resource content array
export type ResourceContent =
  | StructuredContent
  | ActivityReference
  | ActivityBankSelection
  | GroupContent
  | SurveyContent
  | Break;

export type NestableContainer = GroupContent | SurveyContent;

export const isNestableContainer = (content: ResourceContent) => {
  switch (content.type) {
    case 'group':
      return true;
    case 'survey':
      return true;
    default:
      return false;
  }
};

interface NestableContainerCaseOf {
  nestable: (nc: NestableContainer) => any;
  other: (c: ResourceContent) => any;
}

export const maybeNestableContainer = <V>(content: ResourceContent) => ({
  caseOf: ({ nestable, other }: NestableContainerCaseOf) =>
    isNestableContainer(content) ? nestable(content as NestableContainer) : other(content),
});

export const getResourceContentName = (content: ResourceContent): string => {
  switch (content.type) {
    case 'activity-reference':
      return 'Activity';
    case 'content':
      return 'Content';
    case 'group':
      return 'Group';
    case 'survey':
      return 'Survey';
    case 'break':
      return 'Page Break';
    case 'selection':
      return 'Selection';
  }
};

export const canInsert = (content: ResourceContent, parents: ResourceContent[]): boolean => {
  switch (content.type) {
    case 'activity-reference':
      return true;
    case 'content':
      return true;
    case 'group':
      return (
        parents.every((p) => !isGroupWithPurpose(p)) &&
        !content.children.some((c) => groupOrDescendantHasPurpose(c))
      );
    case 'survey':
      return parents.every((p) => !isSurvey(p));
    case 'break':
      return true;
    case 'selection':
      return true;
  }
};

export const isSurvey = (c: ResourceContent) => c.type === 'survey';
export const isGroupWithPurpose = (c: ResourceContent) =>
  c.type === 'group' && c.purpose !== 'none';
export const groupOrDescendantHasPurpose = (c: ResourceContent): boolean => {
  if (isGroupWithPurpose(c)) {
    return true;
  }

  return isNestableContainer(c)
    ? (c as NestableContainer).children.some(groupOrDescendantHasPurpose)
    : false;
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

export const createSurvey = (
  children: Immutable.List<ResourceContent> = Immutable.List([createDefaultStructuredContent()]),
): SurveyContent => ({
  type: 'survey',
  id: guid(),
  title: undefined,
  children,
});

export const createBreak = (): Break => ({
  type: 'break',
  id: guid(),
});

export const createDefaultSelection = () => {
  return {
    type: 'selection',
    id: guid(),
    count: 1,
    logic: { conditions: null },
  } as ActivityBankSelection;
};

export interface StructuredContent {
  type: 'content';
  id: string;
  children: ModelElement[];
}

export interface ActivityBankSelection {
  type: 'selection';
  id: string;
  logic: Bank.Logic;
  count: number;
  children: undefined;
}

export interface ActivityReference {
  type: 'activity-reference';
  id: string;
  activitySlug: ActivitySlug;
  children: [];
}

export type GroupLayout = 'vertical' | 'deck';

export interface GroupContent {
  type: 'group';
  id: string;
  layout: GroupLayout; // TODO define layout types
  purpose: string;
  hidePaginationControls?: boolean;
  children: Immutable.List<ResourceContent>;
}

export interface SurveyContent {
  type: 'survey';
  id: string;
  title: string | undefined;
  hidePaginationControls?: boolean;
  children: Immutable.List<ResourceContent>;
}

export interface Break {
  type: 'break';
  id: string;
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
