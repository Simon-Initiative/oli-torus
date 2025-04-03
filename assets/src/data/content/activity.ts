import { ActivityModelSchema } from 'components/activities/types';
import { Objective } from 'data/content/objective';
import { ActivitySlug, ProjectSlug, ResourceId, ResourceSlug } from 'data/types';

export interface ObjectiveMap {
  [id: string]: ResourceId[];
}

export type SiblingActivity = {
  friendlyName: string; // Activity type friendly name
  title: string; // Activity revision title
  activitySlug: string; // Activity revision slug
};

export type ActivityEditContext = {
  authoringElement: string; // Activity authoring component name
  friendlyName: string; // Activity type friendly name
  description: string; // Activity type description
  typeSlug: string; // Slug of the activity type
  activitySlug: ActivitySlug; // The current resource
  activityId: ResourceId; // The current resource id
  title: string; // The title of the resource
  model: ActivityModelSchema; // Content of the resource
  objectives: ObjectiveMap; // Attached objectives, based on part id
  tags: ResourceId[]; // Attached tags
  optionalContentTypes: any; // Optional content types
  variables: any;
};

export type ProjectResourceContext = {
  projectSlug: ProjectSlug; // The current project
  resourceId: ResourceId; // The id of the parent resource
  resourceSlug: ResourceSlug; // The slug of parent resource
  resourceTitle: string; // The title of the parent resource
  allObjectives: Objective[]; // All objectives
};
