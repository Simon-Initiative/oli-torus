import { makeRequest } from './common';
import { Tag } from 'data/content/tags';
import { ProjectSlug } from 'data/types';

export interface TagsRetrieval {
  result: 'success';
  tags: Tag[];
}

export interface TagCreation {
  result: 'success';
  tag: Tag;
}

export function retrieve(project: ProjectSlug) {
  const params = {
    method: 'GET',
    url: `/tags/project/${project}`,
  };

  return makeRequest<TagsRetrieval>(params);
}

export function create(project: ProjectSlug, title: string) {
  const params = {
    method: 'POST',
    body: JSON.stringify({ title }),
    url: `/tags/project/${project}`,
  };

  return makeRequest<TagCreation>(params);
}
