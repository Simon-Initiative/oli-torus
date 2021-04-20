import { Transforms, Range, Node, Path } from 'slate';
import * as ContentModel from 'data/content/model';
import { KeyboardEvent } from 'react';
import { getNearestBlock } from 'components/editing/utils';
import { ReactEditor } from 'slate-react';

export const onKeyDown = (editor: ReactEditor, e: KeyboardEvent) => {
  if (e.key === 'Enter') {
    handleVoidNewline(editor, e);
  }
};

// Pressing the Enter key on any void block should insert an empty
// paragraph after that node
function handleVoidNewline(editor: ReactEditor, e: KeyboardEvent) {
  if (editor.selection && Range.isCollapsed(editor.selection)) {
    getNearestBlock(editor).lift((node: Node) => {
      const nodeType = node.type as string;
      const schemaItem: ContentModel.SchemaConfig = (ContentModel.schema as any)[nodeType];

      if (schemaItem.isVoid) {
        const path = ReactEditor.findPath(editor, node);
        Transforms.insertNodes(editor, ContentModel.p(), {
          at: Path.next(path),
        });

        Transforms.select(editor, Path.next(path));
      }
    });
  }
}
