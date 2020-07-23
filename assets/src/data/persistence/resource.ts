import { ProjectSlug, ResourceSlug, ObjectiveSlug } from 'data/types';
import { makeRequest } from './common';
import { PageContent, AttachedObjectives } from '../content/resource';

export type ResourceUpdate = {
  title: string,
  objectives: AttachedObjectives,
  content: PageContent,
  releaseLock: boolean,
};

export type Edited = { type: 'success', revisionSlug: string };

export function edit(
  project: ProjectSlug,
  resource: ResourceSlug,
  pendingUpdate: ResourceUpdate,
  releaseLock: boolean) {

  const update = Object.assign({}, pendingUpdate, { releaseLock });

  const params = {
    method: 'PUT',
    body: JSON.stringify({ update }),
    url: `/project/${project}/resource/${resource}`,
  };

  return makeRequest<Edited>(params);
}

export type Page = { id: string, title: string};
export type PagesReceived = { type: 'success', pages: Page[] };

// Requests all of the page details for a course for the purpose
// of constructing links
export function pages(
  project: ProjectSlug, current?: string) {

  const currentSlug = current === undefined
    ? ''
    : `?current=${current}`;

  const params = {
    method: 'GET',
    url: `/project/${project}/link${currentSlug}`,
  };

  return makeRequest<PagesReceived>(params);
}

