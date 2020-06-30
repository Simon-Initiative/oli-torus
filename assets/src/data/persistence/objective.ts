import { ProjectSlug } from 'data/types';
import { makeRequest } from './common';

export type Created = {
  type: 'success',
  revisionSlug: string,
};

export function create(project: ProjectSlug, title: string) {

  const params = {
    method: 'POST',
    body: JSON.stringify({ title }),
    url: `/project/${project}/objectives`,
  };

  return makeRequest<Created>(params);
}
