import { batchedBuffer } from 'utils/common';
import { makeRequest } from './common';

// eslint-disable-next-line
export type ExtrinsicRead = String;

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

export const read = async (key: string) => {
  const params = {
    method: 'GET',
    url: '/blob/' + key,
    hasTextResult: true,
    headers: {
      'Content-Type': 'text/plain',
    },
  };

  const result = await makeRequest<ExtrinsicRead>(params).then((result) => {
    if (typeof result === 'string') {
      const json = JSON.parse(result);
      return json;
    } else {
      return { type: 'ServerError', message: 'Invalid response from server' };
    }
  });

  return { result };
};

export const write = async (key: string, state: any) => {
  const body = JSON.stringify(state);

  const params = {
    method: 'PUT',
    body,
    url: '/blob/' + key,
    hasTextResult: true,
    headers: {
      'Content-Type': 'text/plain',
    },
  };

  const result = await makeRequest<ExtrinsicDelete>(params).then((result) => {
    if (typeof result === 'string') {
      return JSON.parse(result);
    }
    return { type: 'ServerError', message: 'Invalid response from server' };
  });

  return { result };
};

function readGlobal(keys: string[] | null = null) {
  const promises = keys?.map((key) => {
    const params = {
      method: 'GET',
      url: '/blob/user/' + key,
      hasTextResult: true,
      headers: {
        'Content-Type': 'text/plain',
      },
    };

    return makeRequest<ExtrinsicRead>(params);
  });

  if (!promises || promises.length === 0) {
    return Promise.resolve({});
  }

  return Promise.all(promises).then((results) => {
    // Map the array results to an object with top-level keys
    const resultMap: { [key: string]: any } = {};

    keys?.forEach((key, index) => {
      const result = results[index];
      if (typeof result === 'string') {
        try {
          const json = JSON.parse(result);
          resultMap[key] = json;
        } catch (e) {
          resultMap[key] = { type: 'ServerError', message: 'Invalid JSON response' };
        }
      } else {
        resultMap[key] = { type: 'ServerError', message: 'Invalid response from server' };
      }
    });

    return resultMap;
  });
}

export const readGlobalUserState = async (
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
  const currentState = await readGlobalUserState(topLevelKeys, useLocalStorage);

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
  updates: { [topKey: string]: { [key: string]: any } },
  useLocalStorage = false,
) => {
  /*console.log('updateGlobalUserState called', { updates, useLocalStorage });*/
  const result = await batchedUpdate(updates, useLocalStorage);
  /* console.log('updateGlobalUserState result', { result, updates }); */
  return result;
};

export function upsertGlobal(keyValues: KeyValues) {
  const result = Object.keys(keyValues).map((key) => {
    const body = JSON.stringify((keyValues as any)[key]);

    const params = {
      method: 'PUT',
      body,
      url: '/blob/user/' + key,
      hasTextResult: true,
      headers: {
        'Content-Type': 'text/plain',
      },
    };

    return makeRequest<ExtrinsicDelete>(params);
  });

  return Promise.all(result).then((results) => {
    return results.map((result) => {
      if (typeof result === 'string') {
        return JSON.parse(result);
      }
      return { type: 'ServerError', message: 'Invalid response from server' };
    });
  });
}
