import { makeRequest } from './common';
import { ProjectSlug } from 'data/types';

export type Created = {
  result: 'success';
  resourceId: number;
};

export function create(project: ProjectSlug, title: string) {
  const params = {
    method: 'POST',
    body: JSON.stringify({ title }),
    url: `/objectives/project/${project}`,
  };

  return makeRequest<Created>(params);
}
