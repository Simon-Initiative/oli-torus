import { ProjectSlug } from 'data/types';
import { MediaItem, PaginatedResponse } from 'types/media';
import { ServerError, makeRequest } from './common';
import { getBaseURL } from './config';

const fetch = (window as any).fetch;

export type MediaItemCreated = {
  title: 'success';
  url: string;
};

export type MediaItemsDeleted = {
  type: 'success';
  count: number;
};

export type SuperActivityMediaVerification = {
  statuses: Record<string, 'verified' | 'missing'>;
};

export type SuperActivityPackageImport = {
  type: 'success';
  model: any;
};

export type SuperActivityPackageExport = {
  blob: Blob;
  filename: string;
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

export function verifySuperActivityMedia(
  directory: string,
  references: string[],
): Promise<SuperActivityMediaVerification | ServerError> {
  const params = {
    method: 'POST',
    body: JSON.stringify({
      directory,
      references,
    }),
    url: '/superactivity/media/verify',
  };

  return makeRequest<SuperActivityMediaVerification>(params);
}

export function exportSuperActivityPackage(
  model: object,
): Promise<SuperActivityPackageExport | ServerError> {
  return new Promise((resolve, reject) => {
    return fetch(getBaseURL() + '/superactivity/package/export', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model }),
    })
      .then((response: Response) => {
        if (!response.ok) {
          response.text().then((text) => {
            let message;
            try {
              message = JSON.parse(text);
              if (message.message !== undefined) {
                message = message.message;
              }
            } catch (e) {
              message = text;
            }

            reject({
              status: response.status,
              statusText: response.statusText,
              message,
            });
          });
        } else {
          const disposition = response.headers.get('content-disposition') || '';
          const match = disposition.match(/filename="([^"]+)"/);
          const filename = match?.[1] || 'embedded_activity_package.zip';

          response.blob().then((blob) => resolve({ blob, filename }));
        }
      })
      .catch((error: { status: string; statusText: string; message: string }) =>
        reject({
          status: error.status,
          statusText: error.statusText,
          message: error.message,
        }),
      );
  });
}

export function importSuperActivityPackage(
  file: File,
  resourceBase?: string,
): Promise<SuperActivityPackageImport | ServerError> {
  const body = new FormData();
  body.append('upload', file, file.name);
  if (resourceBase) {
    body.append('resourceBase', resourceBase);
  }

  const params = {
    method: 'POST',
    body,
    headers: {},
    url: '/superactivity/package/import',
  };

  return makeRequest<SuperActivityPackageImport>(params);
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
