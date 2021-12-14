import { makeRequest } from './common';
export function edit(project, resource, pendingUpdate, releaseLock) {
    const update = Object.assign({}, pendingUpdate, { releaseLock });
    const params = {
        method: 'PUT',
        body: JSON.stringify({ update }),
        url: `/project/${project}/resource/${resource}`,
    };
    return makeRequest(params);
}
// Requests all of the page details for a course for the purpose
// of constructing links
export function pages(project, current) {
    const currentSlug = current === undefined ? '' : `?current=${current}`;
    const params = {
        method: 'GET',
        url: `/project/${project}/link${currentSlug}`,
    };
    return makeRequest(params);
}
//# sourceMappingURL=resource.js.map