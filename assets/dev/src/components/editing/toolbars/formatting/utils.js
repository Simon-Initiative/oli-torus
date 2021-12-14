import { ReactEditor } from 'slate-react';
import { Range } from 'slate';
export function shouldShowFormattingToolbar(editor) {
    const { selection } = editor;
    return !!selection && ReactEditor.isFocused(editor) && !Range.isCollapsed(selection);
}
//# sourceMappingURL=utils.js.map