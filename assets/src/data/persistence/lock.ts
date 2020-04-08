import { makeRequest, ServerError } from './common';
import { ProjectSlug, ResourceSlug } from '../types';

export type LockResult = Acquired | NotAcquired | ServerError;

export type Acquired = {
  type: 'acquired',
};

export type NotAcquired = {
  type: 'not_acquired',
  user: string,
};

export function releaseLock(
  project: ProjectSlug, resource: ResourceSlug): Promise<LockResult> {

  const params = {
    url: `/project/${project}/${resource}/lock`,
    method: 'DELETE',
  };
  return makeRequest<LockResult>(params);
}

export function acquireLock(
  project: ProjectSlug, resource: ResourceSlug): Promise<LockResult> {

  const params = {
    url: `/project/${project}/${resource}/lock`,
    method: 'POST',
  };
  return makeRequest<LockResult>(params);
}

