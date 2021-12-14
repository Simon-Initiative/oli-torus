import { makeRequest } from './common';
export function retrieve(project, logic, paging) {
    const params = {
        method: 'POST',
        body: JSON.stringify({ logic, paging }),
        url: `/bank/project/${project}`,
    };
    return makeRequest(params);
}
//# sourceMappingURL=bank.js.map