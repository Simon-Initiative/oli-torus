import { normalizeHref } from 'components/editing/models/link/utils';
import guid from 'utils/guid';
export function create(params) {
    return Object.assign({
        id: guid(),
        children: [{ text: '' }],
    }, params);
}
// Helper functions for creating ModelElements
export const td = (text) => create({ type: 'td', children: [{ type: 'p', id: guid(), children: [{ text }] }] });
export const tr = (children) => create({ type: 'tr', children });
export const table = (children) => create({ type: 'table', children });
export const li = () => create({ type: 'li' });
export const ol = () => create({ type: 'ol', children: [li()] });
export const ul = () => create({ type: 'ul', children: [li()] });
export const youtube = (src) => create({ type: 'youtube', src });
export const webpage = (src) => create({ type: 'iframe', src });
export const link = (href = '') => create({ type: 'a', href: normalizeHref(href), target: 'self' });
export const image = (src = '') => create({ type: 'img', src, display: 'block' });
export const audio = (src = '') => create({ type: 'audio', src });
export const p = (children) => {
    if (!children)
        return create({ type: 'p' });
    if (Array.isArray(children))
        return create({ type: 'p', children });
    return create({ type: 'p', children: [{ text: children }] });
};
export const code = () => ({
    type: 'code',
    id: guid(),
    language: 'python',
    children: [{ type: 'code_line', id: guid(), children: [{ text: '' }] }],
});
export const inputRef = () => create({ type: 'input_ref' });
export const popup = () => create({
    type: 'popup',
    trigger: 'hover',
    content: [
        {
            type: 'p',
            children: [{ text: '' }],
            id: guid(),
        },
    ],
});
//# sourceMappingURL=factories.js.map