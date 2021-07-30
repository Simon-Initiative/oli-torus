import { ResourceId } from 'data/types';

export interface PageContent {
  [key: string]: any;
  advancedAuthoring?: boolean;
  advancedDelivery?: boolean;
  displayApplicationChrome?: boolean;
  additionalStylesheets?: string[];
  customCss?: string;
  custom?: any;
  model: any[];
}

export interface PageContext {
  graded: boolean;
  authorEmail: string;
  objectives: any;
  title: string;
  content: PageContent;
  allObjectives?: any[];
  editorMap?: any;
  projectSlug?: string;
  resourceSlug?: string;
  resourceId?: ResourceId;
  activities?: any;
}

export type ActionType = 'navigation' | 'mutateState' | 'feedback';
export type ActionParams = NavigationActionParams | MutateStateActionParams | FeedbackActionParams;
export interface AdaptiveRuleAction {
  type: ActionType;
  params: ActionParams;
}

export interface NavigationActionParams {
  target: string;
}

export interface MutateStateActionParams {
  target: string;
  targetType: number; // CapiVariableTypes
  operator: string;
  value: any;
}

export interface FeedbackActionParams {
  feedback: any;
}

export type NavigationAction = {
  type: 'navigation';
  params: NavigationActionParams;
};

export type MutateStateAction = {
  type: 'mutateState';
  params: MutateStateActionParams;
};

export type FeedbackAction = {
  type: 'feedback';
  params: FeedbackActionParams;
};
