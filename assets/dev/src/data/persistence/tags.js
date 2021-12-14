import { makeRequest } from './common';
export function retrieve(project) {
    const params = {
        method: 'GET',
        url: `/tags/project/${project}`,
    };
    return makeRequest(params);
}
export function create(project, title) {
    const params = {
        method: 'POST',
        body: JSON.stringify({ title }),
        url: `/tags/project/${project}`,
    };
    return makeRequest(params);
}
//# sourceMappingURL=tags.js.map