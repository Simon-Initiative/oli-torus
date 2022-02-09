import { Transforms, Range, Path, Editor } from 'slate';
import { KeyboardEvent } from 'react';
import { getNearestBlock } from 'components/editing/utils';
import { ReactEditor } from 'slate-react';
import { schema, SchemaConfig } from 'data/content/model/schema';
import { Model } from 'data/content/model/elements/factories';

export const onKeyDown = (editor: Editor, e: KeyboardEvent) => {
  if (e.key === 'Enter') {
    handleVoidNewline(editor, e);
  }
};

// Pressing the Enter key on any void block should insert an empty
// paragraph after that node
function handleVoidNewline(editor: Editor, _e: KeyboardEvent) {
  if (editor.selection && Range.isCollapsed(editor.selection)) {
    getNearestBlock(editor).lift((node) => {
      const nodeType = node.type;
      const schemaItem: SchemaConfig = schema[nodeType];

      if (schemaItem.isVoid) {
        const path = ReactEditor.findPath(editor, node);
        Transforms.insertNodes(editor, Model.p(), {
          at: Path.next(path),
        });

        Transforms.select(editor, Path.next(path));
      }
    });
  }
}
