import { ProjectSlug, ActivityTypeSlug } from 'data/types';
import { ActivityModelSchema } from 'components/activities/types';
import { makeRequest } from './common';

export type Created = { type: 'success', revisionSlug: string };

export function createActivity(
  project: ProjectSlug, activityTypeSlug: ActivityTypeSlug, model: ActivityModelSchema) {

  const params = {
    method: 'POST',
    body: JSON.stringify({ model }),
    url: `/project/${project}/activity/${activityTypeSlug}`,
  };

  return makeRequest<Created>(params);
}
