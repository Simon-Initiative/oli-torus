import React from 'react';
import { Point, Range, Editor as SlateEditor, Transforms } from 'slate';
import * as ContentModel from 'data/content/model';

export const onKeyDown = (editor: SlateEditor, e: React.KeyboardEvent) => {
  if (e.key === 'Enter') {
    handleTitleTermination(editor, e);
  }
};

// Handles exiting a header item via Enter key, setting the next block back to normal (p)
function handleTitleTermination(editor: SlateEditor, e: React.KeyboardEvent) {
  if (editor.selection && Range.isCollapsed(editor.selection)) {

    const [match] = SlateEditor.nodes(editor, {
      match: n => n.type === 'h1' || n.type === 'h2'
        || n.type === 'h3' || n.type === 'h4'
        || n.type === 'h5' || n.type === 'h6',
    });

    if (match) {
      const [, path] = match;

      const end = SlateEditor.end(editor, path);

      // If the cursor is at the end of the block
      if (Point.equals(editor.selection.focus, end)) {

        // Insert it ahead of the next node
        const nextMatch = SlateEditor.next(editor, { at: path });
        if (nextMatch) {
          const [, nextPath] = nextMatch;
          Transforms.insertNodes(editor, ContentModel.p(), { at: nextPath });

          const newNext = SlateEditor.next(editor, { at: path });
          if (newNext) {
            const [, newPath] = newNext;
            Transforms.select(editor, newPath);
          }

          // But if there is no next node, insert it at end
        } else {
          Transforms.insertNodes(editor, ContentModel.p(),
          { mode: 'highest', at: SlateEditor.end(editor, []) });

          const newNext = SlateEditor.next(editor, { at: path });
          if (newNext) {
            const [, newPath] = newNext;
            Transforms.select(editor, newPath);
          }
        }

        e.preventDefault();
      }
    }
  }
}
