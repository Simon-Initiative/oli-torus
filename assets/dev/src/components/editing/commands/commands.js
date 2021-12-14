import { Editor } from 'slate';
import { isMarkActive } from '../utils';
export function toggleMark(editor, mark) {
    const isActive = isMarkActive(editor, mark);
    if (isActive) {
        Editor.removeMark(editor, mark);
    }
    else {
        Editor.addMark(editor, mark, true);
    }
}
export function createToggleFormatCommand(attrs) {
    return createCommandDesc(Object.assign(Object.assign({}, attrs), { execute: (context, editor) => toggleMark(editor, attrs.mark), active: (editor) => isMarkActive(editor, attrs.mark) }));
}
export function createButtonCommandDesc(attrs) {
    return createCommandDesc(attrs);
}
function createCommandDesc({ icon, description, execute, active, precondition, }) {
    return Object.assign(Object.assign({ type: 'CommandDesc', icon: () => icon, description: () => description }, (active ? { active } : {})), { command: Object.assign({ execute: (context, editor) => execute(context, editor) }, (precondition ? { precondition } : { precondition: (_editor) => true })) });
}
//# sourceMappingURL=commands.js.map