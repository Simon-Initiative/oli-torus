import * as Immutable from 'immutable';
import { ActivityModelSchema, CreationData } from 'components/activities/types';
import { getDefaultEditor } from 'components/editing/markdown_editor/markdown_util';
import * as Bank from 'data/content/bank';
import { Model } from 'data/content/model/elements/factories';
import { ModelElement, TextDirection } from 'data/content/model/elements/types';
import { Objective } from 'data/content/objective';
import { Tag } from 'data/content/tags';
import { ActivityWithReportOption } from 'data/persistence/resource';
import { GroupTrigger, PageTrigger } from 'data/triggers';
import { ActivitySlug, ActivityTypeSlug, ProjectSlug, ResourceId, ResourceSlug } from 'data/types';
import guid from 'utils/guid';
import { getDefaultTextDirection } from 'utils/useDefaultTextDirection';
import { ActivityEditContext } from './activity';

export type PageContent = {
  model: ResourceContent[];
  bibrefs?: string[];
  trigger?: PageTrigger;
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
  | PurposeGroupContent
  | SurveyContent
  | ReportContent
  | AlternativesContent
  | AlternativeContent
  | Break;

export const isResourceContent = (content: any) =>
  [
    'content',
    'activity-reference',
    'selection',
    'group',
    'survey',
    'report',
    'alternatives',
    'alternative',
    'break',
  ].some((t) => t == content.type);

// Items that can be present as elements in a resource content array and contain
// other resource content as children
export type ResourceGroup =
  | PurposeGroupContent
  | SurveyContent
  | ReportContent
  | AlternativesContent
  | AlternativeContent;

export const isResourceGroup = (content: ResourceContent) =>
  ['group', 'survey', 'report', 'alternatives', 'alternative'].some((t) => t == content.type);

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
    case 'report':
      return 'Report';
    case 'alternatives':
      return 'Alternatives';
    case 'alternative':
      return 'Alternative';
    case 'break':
      return 'Page Break';
    case 'selection':
      return 'Selection';
  }
};

export const allElements = [
  'content',
  'activity-reference',
  'group',
  'survey',
  'report',
  'alternatives',
  'break',
  'selection',
];

export const allowedContentItems = (content: ResourceContent): string[] => {
  switch (content.type) {
    case 'group':
      return allElements;
    case 'survey':
      return allElements;
    case 'report':
      return ['activity-reference'];
    case 'alternatives':
      return ['alternative'];
    case 'alternative':
      return allElements;
    default:
      return [];
  }
};

export const canInsert = (content: ResourceContent, parents: ResourceContent[]): boolean => {
  if (parents.length === 0) {
    // top level root
    return allElements.some((t) => t === content.type);
  }

  const parent = parents[parents.length - 1];
  switch (content.type) {
    case 'group':
      return (
        allowedContentItems(parent).some((t) => t === content.type) &&
        parents.every((p) => !isGroupWithPurpose(p)) &&
        !content.children.some((c) => groupOrDescendantHasPurpose(c))
      );
    case 'survey':
      return (
        allowedContentItems(parent).some((t) => t === content.type) &&
        parents.every((p) => !isSurvey(p))
      );
    case 'report':
      return (
        allowedContentItems(parent).some((t) => t === content.type) &&
        parents.every((p) => !isReport(p))
      );
    default:
      return allowedContentItems(parent).some((t) => t === content.type);
  }
};

export const isSurvey = (c: ResourceContent) => c.type === 'survey';
export const isReport = (c: ResourceContent) => c.type === 'report';
export const isGroupWithPurpose = (c: ResourceContent) =>
  c.type === 'group' && c.purpose !== 'none';
export const groupOrDescendantHasPurpose = (c: ResourceContent): boolean => {
  if (isGroupWithPurpose(c)) {
    return true;
  }

  return isResourceGroup(c)
    ? (c as ResourceGroup).children.some(groupOrDescendantHasPurpose)
    : false;
};

export type OptionalContentTypes = {
  ecl: boolean;
};

// The full context necessary to operate a resource editing session
export type ResourceContext = {
  graded: boolean; // Page or assessment?
  authorEmail: string; // The current author
  projectSlug: ProjectSlug; // The current project
  resourceSlug: ResourceSlug; // The current resource
  resourceId: ResourceId; // The resource id
  hasExperiments: boolean; // Whether the project has experiments
  title: string; // The title of the resource
  content: PageContent; // Content of the resource
  objectives: AttachedObjectives; // Attached objectives
  allObjectives: Objective[]; // All objectives
  allTags: Tag[]; // All available tags
  activityContexts: ActivityEditContext[]; // Contexts for inline activity editing
  optionalContentTypes: OptionalContentTypes; // Optional content types
  creationData?: CreationData; // Creation data for bulk import
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
  { value: 'priorknowledgecheck', label: 'Prior Knowledge Check' },
  { value: 'quiz', label: 'Quiz' },
  { value: 'simulation', label: 'Simulation' },
  { value: 'walkthrough', label: 'Walkthrough' },
];

export const createDefaultStructuredContent = (
  children: ModelElement[] = [Model.p()],
): StructuredContent => ({
  type: 'content',
  id: guid(),
  editor: getDefaultEditor(),
  textDirection: getDefaultTextDirection(),
  children,
});

export const createGroup = (
  purpose = 'none',
  children: Immutable.List<ResourceContent> = Immutable.List([createDefaultStructuredContent()]),
  audience?: AudienceMode,
): PurposeGroupContent => ({
  type: 'group',
  id: guid(),
  children,
  layout: 'vertical',
  purpose,
  audience,
});

export const createAlternatives = (
  alternatives_id: number,
  strategy: AlternativesStrategy,
  children: Immutable.List<AlternativeContent>,
): AlternativesContent => ({
  type: 'alternatives',
  id: guid(),
  children,
  strategy,
  alternatives_id,
});

export const createAlternative = (
  value: string,
  children: Immutable.List<ResourceContent> = Immutable.List([createDefaultStructuredContent()]),
): AlternativeContent => ({
  type: 'alternative',
  id: guid(),
  children,
  value,
});

export const createSurvey = (
  children: Immutable.List<ResourceContent> = Immutable.List([createDefaultStructuredContent()]),
): SurveyContent => ({
  type: 'survey',
  id: guid(),
  title: undefined,
  children,
});

export const createReport = (
  ac: ActivityWithReportOption,
  children: Immutable.List<ResourceContent> = Immutable.List(),
): ReportContent => ({
  type: 'report',
  id: guid(),
  title: undefined,
  children: children,
  activityId: ac.id,
  reportType: ac.type === 'oli_likert' ? 'likert_bar' : undefined,
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

export type EditorType = 'slate' | 'markdown';

export interface StructuredContent {
  type: 'content';
  id: string;
  children: ModelElement[];
  editor?: EditorType;
  textDirection?: TextDirection;
}

export const DEFAULT_EDITOR: EditorType = 'slate';

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

export type AlternativesStrategy =
  | 'select_all'
  | 'user_section_preference'
  | 'upgrade_decision_point';

export type PaginationMode = 'normal' | 'manualReveal' | 'automatedReveal';

export type AudienceMode = 'always' | 'instructor' | 'feedback' | 'never';

export interface PurposeGroupContent {
  type: 'group';
  id: string;
  layout: GroupLayout; // TODO define layout types
  purpose: string;
  audience?: AudienceMode;
  paginationMode?: PaginationMode;
  trigger?: GroupTrigger;
  children: Immutable.List<ResourceContent>;
}

export interface AlternativesContent {
  type: 'alternatives';
  id: string;
  strategy: AlternativesStrategy;
  children: Immutable.List<AlternativeContent>;
  alternatives_id: number;
}

export interface AlternativeContent {
  type: 'alternative';
  id: string;
  value: string;
  children: Immutable.List<ResourceContent>;
}

export interface SurveyContent {
  type: 'survey';
  id: string;
  title: string | undefined;
  children: Immutable.List<ResourceContent>;
}

export interface ReportContent {
  type: 'report';
  id: string;
  title: string | undefined;
  children: Immutable.List<ResourceContent>;
  activityId: string;
  reportType?: string;
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
