import { ProjectSlug } from 'data/types';
import { makeRequest } from './common';

export type Created = {
  result: 'success',
  resourceId: number,
};

export function create(project: ProjectSlug, title: string) {

  const params = {
    method: 'POST',
    body: JSON.stringify({ title }),
    url: `/objectives/project/${project}/objectives`,
  };

  return makeRequest<Created>(params);
}
