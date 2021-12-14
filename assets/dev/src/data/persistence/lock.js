import { makeRequest } from './common';
export function releaseLock(project, resource) {
    const params = {
        url: `/project/${project}/lock/${resource}`,
        method: 'DELETE',
    };
    return makeRequest(params);
}
export function acquireLock(project, resource, withRevision = false) {
    const url = withRevision
        ? `/project/${project}/lock/${resource}?fetch_revision=true`
        : `/project/${project}/lock/${resource}?fetch_revision=false`;
    const params = {
        url,
        method: 'POST',
    };
    return makeRequest(params);
}
//# sourceMappingURL=lock.js.map