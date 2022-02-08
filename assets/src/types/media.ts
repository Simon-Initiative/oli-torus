import * as ModelElements from 'data/content/model/elements/types';

export type MediaLibraryOption = ModelElements.Audio | ModelElements.Image;

export type MediaItem = {
  rev: number;
  dateCreated: string;
  dateUpdated: string;
  guid: string;
  url: string;
  fileName: string;
  mimeType: string;
  fileSize: number;
};

export type MediaRef = {
  resourceId: string;
  guid: string;
};

export type PaginatedResponse<T> = {
  type: 'success';
  offset: number;
  limit: number;
  order: string;
  orderBy: string;
  numResults: number;
  totalResults: number;
  results: T[];
};
