
import { ProjectSlug, ResourceSlug, ObjectiveSlug, ActivitySlug } from 'data/types';
import { Objective } from 'data/content/objective';

import { ActivityModelSchema } from 'components/activities/types';

export interface ObjectiveMap {
  [id: string]: ObjectiveSlug[];
}

export type SiblingActivity = {
  friendlyName: string,           // Activity type friendly name
  title: string,                  // Activity revision title
  activitySlug: string,           // Activity revision slug
};

export type ActivityContext = {
  authoringElement: string,       // Activity authoring component name
  friendlyName: string,           // Activity type friendly name
  description: string,            // Activity type description
  authorEmail: string,            // The current author
  projectSlug: ProjectSlug,       // The current project
  resourceSlug: ResourceSlug,     // The slug of parent resource
  resourceTitle: string,          // The title of the parent resource
  activitySlug: ActivitySlug,     // The current resource
  title: string,                  // The title of the resource
  model: ActivityModelSchema,     // Content of the resource
  objectives: ObjectiveMap,       // Attached objectives, based on part id
  allObjectives: Objective[],     // All objectives
};
