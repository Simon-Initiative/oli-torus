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
  resource_id?: ResourceId;
  activities?: any;
}
