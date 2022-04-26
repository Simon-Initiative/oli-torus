import { BibEntry, Paging } from 'data/content/bibentry';
import { ProjectSlug } from 'data/types';
import { makeRequest } from './common';

export interface BibEntrysRetrieval {
  result: 'success';
  bibEntrys: BibEntry[];
}

export interface BibEntryCreation {
  result: 'success';
  bitEntry: BibEntry;
}

export interface PagedBibRetrieval {
  result: 'success';
  queryResult: PagedBibResult;
}

export interface PagedBibResult {
  rows: BibEntry[];
  rowCount: number;
  totalCount: number;
}

export function retrieve(project: ProjectSlug, paging: Paging) {
  const params = {
    method: 'POST',
    body: JSON.stringify({ paging }),
    url: `/bibs/project/${project}/retrieve`,
  };

  return makeRequest<PagedBibRetrieval>(params);
}

export function fetch(project: ProjectSlug) {
  const params = {
    method: 'GET',
    url: `/bibs/project/${project}`,
  };

  return makeRequest<BibEntrysRetrieval>(params);
}

export function create(project: ProjectSlug, title: string, content: string) {
  const params = {
    method: 'POST',
    body: JSON.stringify({ title, content }),
    url: `/bibs/project/${project}`,
  };

  return makeRequest<BibEntryCreation>(params);
}
