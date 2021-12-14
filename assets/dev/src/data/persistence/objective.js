import { makeRequest } from './common';
export function create(project, title) {
    const params = {
        method: 'POST',
        body: JSON.stringify({ title }),
        url: `/objectives/project/${project}`,
    };
    return makeRequest(params);
}
//# sourceMappingURL=objective.js.map