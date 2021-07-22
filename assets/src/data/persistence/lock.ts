import { makeRequest, ServerError } from './common';
import { ProjectSlug, ResourceSlug } from '../types';

export type LockResult = Acquired | Released | NotAcquired | ServerError;

export type Acquired = {
  type: 'acquired',
  revision?: any,
};

export type NotAcquired = {
  type: 'not_acquired',
  user: string,
};

export type Released = {
  type: 'released',
};

export function releaseLock(
  project: ProjectSlug, resource: ResourceSlug): Promise<LockResult> {

  const params = {
    url: `/project/${project}/lock/${resource}`,
    method: 'DELETE',
  };
  return makeRequest<LockResult>(params);
}

export function acquireLock(
  project: ProjectSlug, resource: ResourceSlug, withRevision = false): Promise<LockResult> {

  const url = withRevision
    ? `/project/${project}/lock/${resource}?fetch_revision=true`
    : `/project/${project}/lock/${resource}?fetch_revision=false`;

  const params = {
    url,
    method: 'POST',
  };
  return makeRequest<LockResult>(params);
}

