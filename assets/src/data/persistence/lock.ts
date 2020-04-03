import { makeRequest, ServerError } from './common';
import { ProjectId, ResourceId } from '../types';

export type LockResult = LockSuccess | LockFailure | ServerError;

export type LockSuccess = {
  type: 'success',
};

export type LockFailure = {
  type: 'failure',
  lockedBy: string,
  lockedAt: Date,
};

export function releaseLock(
  project: ProjectId, resource: ResourceId): Promise<LockResult> {

  const params = {
    url: `/project/${project}/${resource}/lock`,
    method: 'DELETE',
  };
  return makeRequest<LockResult>(params);
}

export function acquireLock(
  project: ProjectId, resource: ResourceId): Promise<LockResult> {

  const params = {
    url: `/project/${project}/${resource}/lock`,
    method: 'POST',
  };
  return makeRequest<LockResult>(params);
}

