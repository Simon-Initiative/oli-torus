import { ProjectSlug, ActivityTypeSlug, ResourceId } from 'data/types';
import {
  ActivityModelSchema,
  Feedback,
  FeedbackAction,
  PartResponse,
} from 'components/activities/types';
import { ObjectiveMap } from 'data/content/activity';
import { makeRequest } from './common';

export type ActivityUpdate = {
  title: string;
  objectives: ObjectiveMap;
  content: ActivityModelSchema;
  authoring?: any;
};

export type Created = {
  result: 'success';
  revisionSlug: string;
  resourceId: ResourceId;
};

export type Updated = {
  result: 'success';
  revisionSlug: string;
};

export type Deleted = {
  result: 'success';
};

export type Transformed = {
  result: 'success';
  transformed: null | ActivityModelSchema;
};

export type Evaluated = {
  result: 'success';
  evaluations: (
    | { feedback: Feedback; part_id: string; result: { out_of: number; score: number } }
    | { error: string; part_id: string }
  )[];
};

export type Retrieved = {
  result: 'success';
  resourceId: ResourceId;
  title: string;
  activityType: number;
  content: ActivityModelSchema;
  authoring?: any;
  objectives?: any; // TODO typing
};

export type BulkRetrieved = {
  result: 'success';
  results: Retrieved[];
};

export type Edited = { result: 'success'; revisionSlug: string };

export const getActivityForAuthoring = (projectSlug: string, activityId: ResourceId) => {
  const params = {
    method: 'GET',
    url: `/storage/project/${projectSlug}/resource/${activityId}`,
  };

  return makeRequest<Retrieved>(params);
};

export const getBulkActivitiesForAuthoring = async (
  projectSlug: string,
  activityIds: ResourceId[],
) => {
  const params = {
    method: 'POST',
    url: `/storage/project/${projectSlug}/resource`,
    body: JSON.stringify({ resourceIds: activityIds }),
  };

  const response = await makeRequest<BulkRetrieved>(params);
  if (response.result !== 'success') {
    throw new Error(`Server ${response.status} error: ${response.message}`);
  }

  return response.results.map((result: Retrieved) => {
    const { resourceId: id, activityType, title, content, authoring, objectives } = result;
    return {
      id,
      activityType,
      title,
      content,
      authoring,
      objectives,
    };
  });
};

export const getActivityForDelivery = (sectionSlug: string, activityId: ResourceId) => {
  const params = {
    method: 'GET',
    url: `/storage/course/${sectionSlug}/resource/${activityId}`,
  };

  return makeRequest<Retrieved>(params);
};

export const getBulkActivitiesForDelivery = async (
  sectionSlug: string,
  activityIds: ResourceId[],
) => {
  const params = {
    method: 'POST',
    url: `/storage/course/${sectionSlug}/resource`,
    body: JSON.stringify({ resourceIds: activityIds }),
  };

  const response = await makeRequest<BulkRetrieved>(params);
  if (response.result !== 'success') {
    throw new Error(`Server ${response.status} error: ${response.message}`);
  }

  return response.results.map((result: Retrieved) => {
    const { resourceId: id, title, content } = result;
    return {
      id,
      title,
      content,
    };
  });
};

export function create(
  project: ProjectSlug,
  activityTypeSlug: ActivityTypeSlug,
  model: ActivityModelSchema,
  objectives: ResourceId[],
  scope = 'embedded',
) {
  const params = {
    method: 'POST',
    body: JSON.stringify({ model, objectives, scope }),
    url: `/project/${project}/activity/${activityTypeSlug}`,
  };

  return makeRequest<Created>(params);
}

export function deleteActivity(project: ProjectSlug, resourceId: ResourceId) {
  const params = {
    method: 'DELETE',
    url: `/storage/project/${project}/resource/${resourceId}?lock=${resourceId}`,
  };

  return makeRequest<Deleted>(params);
}

export function createBanked(
  project: ProjectSlug,
  activityTypeSlug: ActivityTypeSlug,
  model: ActivityModelSchema,
  objectives: ResourceId[],
) {
  return create(project, activityTypeSlug, model, objectives, 'banked');
}

export function edit(
  project: ProjectSlug,
  resource: ResourceId,
  activity: ResourceId,
  pendingUpdate: ActivityUpdate,
  releaseLock: boolean,
) {
  const update = Object.assign({}, pendingUpdate, { releaseLock });
  update.content = Object.assign({}, update.content);

  // Here we pull the "authoring" key out of "content" and elevate it
  // as a top-level key
  if (update.content.authoring !== undefined) {
    update.authoring = update.content.authoring;
    delete update.content.authoring;
  }

  const params = {
    method: 'PUT',
    body: JSON.stringify(update),
    url: `/storage/project/${project}/resource/${activity}?lock=${resource}`,
  };

  return makeRequest<Updated>(params);
}

export function transform(model: ActivityModelSchema) {
  const params = {
    method: 'PUT',
    body: JSON.stringify({ model }),
    url: '/project/test/transform',
  };

  return makeRequest<Transformed>(params);
}

export function evaluate(model: ActivityModelSchema, partResponses: PartResponse[]) {
  const params = {
    method: 'PUT',
    body: JSON.stringify({ model, partResponses }),
    url: '/project/test/evaluate',
  };

  return makeRequest<Evaluated>(params);
}
