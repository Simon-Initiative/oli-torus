import { KeyboardEvent } from 'react';
import { Range, Editor as SlateEditor, Transforms } from 'slate';

const blocksToDelete: string[] = ['table'];

const matchBlockToDelete = (node: any) => blocksToDelete.includes(node.type);

const deleteOrBackspaceBlock = (
  editor: SlateEditor,
  e: KeyboardEvent,
  direction: 'before' | 'after',
) => {
  try {
    if (
      (e.key === 'Delete' || e.key === 'Backspace') &&
      editor.selection &&
      Range.isCollapsed(editor.selection)
    ) {
      const [currentCursorPosition] = Range.edges(editor.selection);

      const nextCursorPosition =
        direction === 'before'
          ? SlateEditor.before(editor, currentCursorPosition)
          : SlateEditor.after(editor, currentCursorPosition);

      if (!nextCursorPosition || !currentCursorPosition) return;

      // If the cursor is currently inside a deletable block, do not delete the whole block.
      const currentDeletableItem = SlateEditor.above(editor, {
        at: currentCursorPosition,
        match: matchBlockToDelete,
      });

      // If the cursor would end up inside a deletable block, delete the whole block.
      const nextDeletableItem = SlateEditor.above(editor, {
        at: nextCursorPosition,
        match: matchBlockToDelete,
      });

      if (!currentDeletableItem && nextDeletableItem) {
        Transforms.removeNodes(editor, { at: nextDeletableItem[1] });
        e.preventDefault();
      }
    }
  } catch (error) {
    console.error(`An error occurred while handling ${direction} keydown:`, error);
  }
};

export const deleteBlockKeyDown = (editor: SlateEditor, e: KeyboardEvent) => {
  deleteOrBackspaceBlock(editor, e, 'after');
};

export const backspaceBlockKeyDown = (editor: SlateEditor, e: KeyboardEvent) => {
  deleteOrBackspaceBlock(editor, e, 'before');
};
