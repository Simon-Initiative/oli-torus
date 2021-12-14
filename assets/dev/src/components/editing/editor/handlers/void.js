import { Transforms, Range, Path } from 'slate';
import { getNearestBlock } from 'components/editing/utils';
import { ReactEditor } from 'slate-react';
import { schema } from 'data/content/model/schema';
import { p } from 'data/content/model/elements/factories';
export const onKeyDown = (editor, e) => {
    if (e.key === 'Enter') {
        handleVoidNewline(editor, e);
    }
};
// Pressing the Enter key on any void block should insert an empty
// paragraph after that node
function handleVoidNewline(editor, _e) {
    if (editor.selection && Range.isCollapsed(editor.selection)) {
        getNearestBlock(editor).lift((node) => {
            const nodeType = node.type;
            const schemaItem = schema[nodeType];
            if (schemaItem.isVoid) {
                const path = ReactEditor.findPath(editor, node);
                Transforms.insertNodes(editor, p(), {
                    at: Path.next(path),
                });
                Transforms.select(editor, Path.next(path));
            }
        });
    }
}
//# sourceMappingURL=void.js.map