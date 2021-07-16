import { Logic, Paging, BankedActivity } from 'data/content/bank';
import { ProjectSlug } from 'data/types';
import { makeRequest } from './common';


export interface PagedBankRetrieval {
  result: 'success';
  queryResult: PagedBankResult;
};

export interface PagedBankResult {
  rows: BankedActivity[];
  rowCount: number;
  totalCount: number;
}

export function retrieve(
  project: ProjectSlug,
  logic: Logic,
  paging: Paging

) {
  const params = {
    method: 'POST',
    body: JSON.stringify({ logic, paging }),
    url: `/bank/project/${project}`,
  };

  return makeRequest<PagedBankRetrieval>(params);
}

