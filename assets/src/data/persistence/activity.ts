import * as Immutable from 'immutable';
import { ProjectSlug, ActivityTypeSlug, ActivitySlug, ObjectiveSlug, ResourceSlug } from 'data/types';
import { ActivityModelSchema } from 'components/activities/types';
import { makeRequest } from './common';

export type ActivityUpdate = {
  title: string,
  objectives: Immutable.Map<string, Immutable.List<ObjectiveSlug>>,
  content: ActivityModelSchema,
};

export type Created = { type: 'success', revisionSlug: string };
export type Edited = { type: 'success', revisionSlug: string };

export function create(
  project: ProjectSlug, activityTypeSlug: ActivityTypeSlug, model: ActivityModelSchema) {

  const params = {
    method: 'POST',
    body: JSON.stringify({ model }),
    url: `/project/${project}/activity/${activityTypeSlug}`,
  };

  return makeRequest<Created>(params);
}

export function edit(
  project: ProjectSlug, resource: ResourceSlug,
  activity: ActivitySlug, update: ActivityUpdate) {

  const params = {
    method: 'PUT',
    body: JSON.stringify({ update }),
    url: `/project/${project}/resource/${resource}/activity/${activity}`,
  };

  return makeRequest<Created>(params);
}
