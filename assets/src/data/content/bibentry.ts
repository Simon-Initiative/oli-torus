import { ResourceId } from 'data/types';

export interface Paging {
  offset: number;
  limit: number;
}

export interface BibEntry {
  id: ResourceId;
  slug: string;
  title: string;
  content: any;
  ordinal?: number;
}

export function paging(offset: number, limit: number): Paging {
  return {
    offset,
    limit,
  };
}
