import { SectionSlug } from 'data/types';
import { makeRequest } from './common';

export type ExtrinsicRead = Object;
export type ExtrinsicUpsert = {
  result: "success"
};
export type ExtrinsicDelete = {
  result: "success"
};

export function read_global(keys: string[] | null = null) {

  // Phoenix handles arrays like foo[]=bar&foo[]=baz&foo[]=qux.
  const keyParams = keys === null
    ? ''
    : '?' + keys.reduce(
      (p, k) => {
        return p + '&keys[]=' + k;
      },
      '',
    ).substr(1);

  const params = {
    method: 'GET',
    url: '/state' + keyParams,
  };

  return makeRequest<ExtrinsicRead>(params);
}

export function delete_global(keys: string[]) {

  // Phoenix handles arrays like foo[]=bar&foo[]=baz&foo[]=qux.
  const keyParams = '?' + keys.reduce(
    (p, k) => {
      return p + '&keys[]=' + k;
    },
    '',
  ).substr(1);

  const params = {
    method: 'DELETE',
    url: '/state' + keyParams,
  };

  return makeRequest<ExtrinsicRead>(params);
}

export function upsert_global(keyValues: Object) {

  const params = {
    method: 'PUT',
    body: JSON.stringify(keyValues),
    url: '/state',
  };

  return makeRequest<ExtrinsicDelete>(params);
}
