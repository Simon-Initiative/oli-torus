import { makeRequest } from './common';
export function fetchPreferences() {
    const params = {
        url: '/account/preferences',
        method: 'GET',
    };
    return makeRequest(params);
}
export function updatePreferences(preferences) {
    const params = {
        url: '/account/preferences',
        method: 'POST',
        body: JSON.stringify(preferences),
        hasTextResult: true,
    };
    return makeRequest(params);
}
//# sourceMappingURL=preferences.js.map