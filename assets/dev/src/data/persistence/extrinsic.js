var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { makeRequest } from './common';
export function readGlobal(keys = null) {
    const params = {
        method: 'GET',
        url: '/state' + toKeyParams(keys),
    };
    return makeRequest(params);
}
export const readGlobalUserState = (keys = null, useLocalStorage = false) => __awaiter(void 0, void 0, void 0, function* () {
    let result = {};
    if (useLocalStorage) {
        // localStorage API doesn't support the "get all" behavior, so we need to put everything into a single object
        const storedUserState = JSON.parse(localStorage.getItem('torus.userState') || '{}');
        if (keys) {
            keys.forEach((key) => {
                result[key] = storedUserState[key];
            });
        }
        else {
            result = storedUserState;
        }
    }
    else {
        const serverUserState = yield readGlobal(keys);
        // merge server state with result
        if (serverUserState.type !== 'ServerError') {
            result = serverUserState;
        }
    }
    return result;
});
export const updateGlobalUserState = (updates, useLocalStorage = false) => __awaiter(void 0, void 0, void 0, function* () {
    const topLevelKeys = Object.keys(updates);
    const currentState = yield readGlobalUserState(topLevelKeys, useLocalStorage);
    const newState = Object.assign({}, currentState);
    topLevelKeys.forEach((topKey) => {
        const actualKeys = Object.keys(updates[topKey]);
        actualKeys.forEach((actualKey) => {
            newState[topKey] = Object.assign(Object.assign({}, newState[topKey]), { [actualKey]: updates[topKey][actualKey] });
        });
    });
    if (useLocalStorage) {
        const existingState = localStorage.getItem('torus.userState') || '{}';
        const parsedState = JSON.parse(existingState);
        const mergedState = Object.assign(Object.assign({}, parsedState), newState);
        localStorage.setItem('torus.userState', JSON.stringify(mergedState));
    }
    else {
        yield upsertGlobal(newState);
    }
    return newState;
});
export function deleteGlobal(keys) {
    const params = {
        method: 'DELETE',
        url: '/state' + toKeyParams(keys),
    };
    return makeRequest(params);
}
export function upsertGlobal(keyValues) {
    const params = {
        method: 'PUT',
        body: JSON.stringify(keyValues),
        url: '/state',
    };
    return makeRequest(params);
}
export function readSection(slug, keys = null) {
    const params = {
        method: 'GET',
        url: `/state/course/${slug}` + toKeyParams(keys),
    };
    return makeRequest(params);
}
export function deleteSection(slug, keys) {
    const params = {
        method: 'DELETE',
        url: `/state/course/${slug}` + toKeyParams(keys),
    };
    return makeRequest(params);
}
export function upsertSection(slug, keyValues) {
    const params = {
        method: 'PUT',
        body: JSON.stringify(keyValues),
        url: `/state/course/${slug}`,
    };
    return makeRequest(params);
}
// Take a list of string key names and turn it into the form expected by
// Phoenix: foo[]=bar&foo[]=baz&foo[]=qux.
function toKeyParams(keys = null) {
    return keys === null
        ? ''
        : '?' +
            keys
                .reduce((p, k) => {
                return p + '&keys[]=' + k;
            }, '')
                .substr(1);
}
//# sourceMappingURL=extrinsic.js.map