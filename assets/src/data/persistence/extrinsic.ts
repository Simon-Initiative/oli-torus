import { SectionSlug } from 'data/types';
import { batchedBuffer } from 'utils/common';
import * as Blob from './blob';
import { makeRequest } from './common';

// eslint-disable-next-line
export type ExtrinsicRead = Object;

// eslint-disable-next-line
export type KeyValues = Object;
export type ExtrinsicUpsert = {
  result: 'success';
};
export type ExtrinsicDelete = {
  result: 'success';
};
const setQ = new Set();
const lastSet = () => {
  const arr = Array.from(setQ);
  return arr[arr.length - 1];
};

export function readGlobal(keys: string[] | null = null) {
  const params = {
    method: 'GET',
    url: '/state' + toKeyParams(keys),
  };

  const result = makeRequest<ExtrinsicRead>(params);

  /* console.log('GET DATA FROM STATE', { keys, params, result }); */

  return result;
}

export const readGlobalUserState = async (
  provider: 'deprecated' | 'new',
  keys: string[] | null = null,
  useLocalStorage = false,
) => {
  if (provider === 'deprecated') {
    return deprecatedReadGlobalUserState(keys, useLocalStorage);
  }
  return Blob.readGlobalUserState(keys, useLocalStorage);
};

const deprecatedReadGlobalUserState = async (
  keys: string[] | null = null,
  useLocalStorage = false,
) => {
  let result: any = {};
  if (useLocalStorage) {
    // localStorage API doesn't support the "get all" behavior, so we need to put everything into a single object
    const storedUserState = JSON.parse(localStorage.getItem('torus.userState') || '{}');
    if (keys) {
      keys.forEach((key) => {
        result[key] = storedUserState[key];
      });
    } else {
      result = storedUserState;
    }
  } else {
    if (lastSet()) {
      await lastSet();
    }
    if (keys) {
      //if cache does not have any of the requested keys, we should make the server call
      const serverUserState = await readGlobal(keys);
      // merge server state with result
      if ((serverUserState as any).type !== 'ServerError') {
        result = serverUserState;
      }
    }
  }
  return result;
};

export const internalUpdateGlobalUserState = async (
  updates: { [topKey: string]: { [key: string]: any } },
  useLocalStorage = false,
) => {
  /* console.log('updateGlobalUserState', updates); */
  const topLevelKeys = Object.keys(updates);
  const currentState = await deprecatedReadGlobalUserState(topLevelKeys, useLocalStorage);

  const newState = { ...currentState };
  topLevelKeys.forEach((topKey) => {
    const actualKeys = Object.keys(updates[topKey]);
    actualKeys.forEach((actualKey) => {
      newState[topKey] = { ...newState[topKey], [actualKey]: updates[topKey][actualKey] };
    });
  });

  if (useLocalStorage) {
    const existingState = localStorage.getItem('torus.userState') || '{}';
    const parsedState = JSON.parse(existingState);

    const mergedState = { ...parsedState, ...newState };

    localStorage.setItem('torus.userState', JSON.stringify(mergedState));
  } else {
    const op = upsertGlobal(newState);
    setQ.add(op);
    await op;
    setQ.delete(op);
  }
  return newState;
};

const updateInterval = 300;
const [batchedUpdate] = batchedBuffer(internalUpdateGlobalUserState, updateInterval);

export const updateGlobalUserState = async (
  provider: 'deprecated' | 'new',
  updates: { [topKey: string]: { [key: string]: any } },
  useLocalStorage = false,
) => {
  if (provider === 'deprecated') {
    return deprecatedUpdateGlobalUserState(updates, useLocalStorage);
  }
  return Blob.updateGlobalUserState(updates, useLocalStorage);
};

export const deprecatedUpdateGlobalUserState = async (
  updates: { [topKey: string]: { [key: string]: any } },
  useLocalStorage = false,
) => {
  /*console.log('updateGlobalUserState called', { updates, useLocalStorage });*/
  const result = await batchedUpdate(updates, useLocalStorage);
  /* console.log('updateGlobalUserState result', { result, updates }); */
  return result;
};

export function deleteGlobal(keys: string[]) {
  const params = {
    method: 'DELETE',
    url: '/state' + toKeyParams(keys),
  };

  return makeRequest<ExtrinsicRead>(params);
}

export function upsertGlobal(keyValues: KeyValues) {
  const params = {
    method: 'PUT',
    body: JSON.stringify(keyValues),
    url: '/state',
  };

  const result = makeRequest<ExtrinsicDelete>(params);

  /* console.log('UPSERT DATA TO STATE', { params, result }); */

  return result;
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

export function upsertSection(slug: SectionSlug, keyValues: KeyValues) {
  const params = {
    method: 'PUT',
    body: JSON.stringify(keyValues),
    url: `/state/course/${slug}`,
  };

  return makeRequest<ExtrinsicDelete>(params);
}

export function readAttempt(slug: SectionSlug, attemptGuid: string, keys: string[] | null = null) {
  const params = {
    method: 'GET',
    url: `/state/course/${slug}/resource_attempt/${attemptGuid}` + toKeyParams(keys),
  };

  return makeRequest<ExtrinsicRead>(params);
}

export function deleteAttempt(slug: SectionSlug, attemptGuid: string, keys: string[]) {
  const params = {
    method: 'DELETE',
    url: `/state/course/${slug}/resource_attempt/${attemptGuid}` + toKeyParams(keys),
  };

  return makeRequest<ExtrinsicRead>(params);
}

export function upsertAttempt(slug: SectionSlug, attemptGuid: string, keyValues: KeyValues) {
  const params = {
    method: 'PUT',
    body: JSON.stringify(keyValues),
    url: `/state/course/${slug}/resource_attempt/${attemptGuid}`,
  };

  return makeRequest<ExtrinsicDelete>(params);
}

// Take a list of string key names and turn it into the form expected by
// Phoenix: foo[]=bar&foo[]=baz&foo[]=qux.
function toKeyParams(keys: string[] | null = null) {
  return keys === null
    ? ''
    : '?' +
        keys
          .reduce((p, k) => {
            return p + '&keys[]=' + k;
          }, '')
          .substr(1);
}
