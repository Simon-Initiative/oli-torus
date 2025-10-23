import { ProjectSlug } from 'data/types';
import { MediaItem, PaginatedResponse } from 'types/media';
import { ServerError, makeRequest } from './common';

export type MediaItemCreated = {
  title: 'success';
  url: string;
};

export type MediaItemsDeleted = {
  type: 'success';
  count: number;
};

export function getFileName(file: File) {
  const fileNameWithDot = file.name.slice(
    0,
    file.name.indexOf('.') !== -1 ? file.name.indexOf('.') + 1 : file.name.length,
  );
  const extension =
    file.name.indexOf('.') !== -1 ? file.name.substr(file.name.indexOf('.') + 1).toLowerCase() : '';

  return fileNameWithDot + extension;
}

export function encodeFile(file: File): Promise<string> {
  const reader = new FileReader();

  if (file) {
    return new Promise((resolve, reject) => {
      reader.addEventListener(
        'load',
        () => {
          if (reader.result === '') {
            // Max string-size in V8 is 512mb, if your base64 string is bigger than that,
            // file-reader will return an empty string here
            reject('failed to encode');
          } else if (reader.result !== null) {
            resolve((reader.result as string).substr((reader.result as string).indexOf(',') + 1));
          } else {
            reject('failed to encode');
          }
        },
        false,
      );

      reader.readAsDataURL(file);
    });
  }
  return Promise.reject('file was null');
}

export function createMedia(
  project: ProjectSlug,
  file: File,
): Promise<MediaItemCreated | ServerError> {
  const fileName = getFileName(file);
  return encodeFile(file).then((encoding: string) => {
    const body = {
      file: encoding,
      name: fileName,
    };
    const params = {
      method: 'POST',
      body: JSON.stringify(body),
      url: `/media/project/${project}`,
    };

    return makeRequest<MediaItemCreated>(params);
  });
}

export function createSuperActivityMedia(
  directory: string,
  file: File,
): Promise<MediaItemCreated | ServerError> {
  const fileName = getFileName(file);
  return encodeFile(file).then((encoding: string) => {
    const body = {
      file: encoding,
      name: fileName,
      directory: directory,
    };
    const params = {
      method: 'POST',
      body: JSON.stringify(body),
      url: '/superactivity/media',
    };

    return makeRequest<MediaItemCreated>(params);
  });
}

export function deleteMedia(
  project: ProjectSlug,
  mediaIds: string[],
): Promise<MediaItemsDeleted | ServerError> {
  const params = {
    method: 'POST',
    url: `/media/project/${project}/delete`,
    body: JSON.stringify({ mediaItemIds: mediaIds }),
  };

  return makeRequest<MediaItemsDeleted>(params);
}

export function fetchMedia(
  project: ProjectSlug,
  offset?: number,
  limit?: number,
  mimeFilter?: string[],
  urlFilter?: string,
  searchText?: string,
  orderBy?: string,
  order?: string,
): Promise<PaginatedResponse<MediaItem> | ServerError> {
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
    url: `/media/project/${project}`,
  };

  return makeRequest<PaginatedResponse<MediaItem>>(params);
}
