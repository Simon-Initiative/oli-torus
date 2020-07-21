import { ProjectSlug } from 'data/types';
import { makeRequest, ServerError } from './common';
import { PaginatedResponse, MediaItem } from 'types/media';

export type MediaItemCreated = {
  title: 'success',
  url: string,
};

function getFileName(file: File) {
  const fileNameWithDot = file.name.slice(
    0, file.name.indexOf('.') !== -1
      ? file.name.indexOf('.') + 1
      : file.name.length);
  const extension = file.name.indexOf('.') !== -1
    ? file.name.substr(file.name.indexOf('.') + 1).toLowerCase()
    : '';

  return fileNameWithDot + extension;
}

function encodeFile(file: File) : Promise<string> {

  const reader = new FileReader();

  if (file) {
    return new Promise((resolve, reject) => {

      reader.addEventListener('load', () => {

        if (reader.result !== null) {
          resolve((reader.result as string).substr((reader.result as string).indexOf(',') + 1));
        } else {
          reject('failed to encode');
        }

      }, false);

      reader.readAsDataURL(file);

    });
  }
  return Promise.reject('file was null');

}

export function createMedia(
  project: ProjectSlug, file: File) : Promise<MediaItemCreated | ServerError> {

  const fileName = getFileName(file);
  return encodeFile(file)
  .then((encoding: string) => {

    const body = {
      file: encoding,
      name: fileName,
    };
    const params = {
      method: 'POST',
      body: JSON.stringify(body),
      url: `/project/${project}/media`,
    };

    return makeRequest<MediaItemCreated>(params);
  });

}

export function fetchMedia(
  project: ProjectSlug, offset?: number, limit?: number,
  mimeFilter?: string[], urlFilter?: string, searchText?: string, orderBy?: string,
  order?: string): Promise<PaginatedResponse<MediaItem> | ServerError> {

  const query = Object.assign(
    {},
    offset ? { offset } : {},
    limit ? { limit } : {},
    mimeFilter ? { mimeFilter } : {},
    urlFilter ? { urlFilter } : {},
    searchText ? { searchText } : {},
    orderBy ? { orderBy } : {},
    order ? { order } : {},
  );

  const params = {
    method: 'GET',
    query,
    url: `/project/${project}/media`,
  };

  return makeRequest<PaginatedResponse<MediaItem>>(params);
}

