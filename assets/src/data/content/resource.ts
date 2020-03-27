import { ModelElement } from './model';
export type ResourceContent = StructuredContent | ActivityReference;

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

export interface StructuredContent {
  type: 'content';
  id: number;
  children: ModelElement[];
  purpose: ContentPurpose;
}

export interface ActivityReference {
  type: 'activity';
  id: number;
  idRef: number;
  purpose: ActivityPurpose;
}
