import { SectionSlug } from 'data/types';
import { makeRequest } from './common';

export type ExtrinsicRead = Object;
export type ExtrinsicUpsert = {
  result: 'success',
};
export type ExtrinsicDelete = {
  result: 'success',
};

export function readGlobal(keys: string[] | null = null) {

  const params = {
    method: 'GET',
    url: '/state' + toKeyParams(keys),
  };

  return makeRequest<ExtrinsicRead>(params);
}

export function deleteGlobal(keys: string[]) {

  const params = {
    method: 'DELETE',
    url: '/state' + toKeyParams(keys),
  };

  return makeRequest<ExtrinsicRead>(params);
}

export function upsertGlobal(keyValues: Object) {

  const params = {
    method: 'PUT',
    body: JSON.stringify(keyValues),
    url: '/state',
  };

  return makeRequest<ExtrinsicDelete>(params);
}


export function readSection(slug: SectionSlug, keys: string[] | null = null) {

  const params = {
    method: 'GET',
    url: `/state/course/${slug}` + toKeyParams(keys),
  };

  return makeRequest<ExtrinsicRead>(params);
}

export function deleteSection(slug: SectionSlug, keys: string[]) {

  const params = {
    method: 'DELETE',
    url: `/state/course/${slug}` + toKeyParams(keys),
  };

  return makeRequest<ExtrinsicRead>(params);
}

export function upsertSection(slug: SectionSlug, keyValues: Object) {

  const params = {
    method: 'PUT',
    body: JSON.stringify(keyValues),
    url: `/state/course/${slug}`,
  };

  return makeRequest<ExtrinsicDelete>(params);
}

// Take a list of string key names and turn it into the form expected by
// Phoenix: foo[]=bar&foo[]=baz&foo[]=qux.
function toKeyParams(keys: string[] | null = null) {

  keys === null
    ? ''
    : '?' + keys.reduce(
      (p, k) => {
        return p + '&keys[]=' + k;
      },
      '',
    ).substr(1);
}
