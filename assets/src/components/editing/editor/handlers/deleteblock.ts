import { KeyboardEvent } from 'react';
import { Editor, Path, Range, Editor as SlateEditor, Transforms } from 'slate';

const blocksToDelete: string[] = ['table'];
const internalBlocks: string[] = ['td', 'th'];

const matchBlockToDelete = (node: any) => blocksToDelete.includes(node.type);
const matchInternalBlock = (node: any) => internalBlocks.includes(node.type);

const deleteOrBackspaceBlock = (
  editor: SlateEditor,
  e: KeyboardEvent,
  direction: 'before' | 'after',
) => {
  try {
    if (editor.selection && !Range.isCollapsed(editor.selection)) {
      // When the range isn't collapsed, we want to delete the overall table if the selection spans more than one cell.
      const [start, end] = Range.edges(editor.selection);
      const startItem = SlateEditor.above(editor, {
        at: start,
        match: matchInternalBlock,
      });
      const endItem = SlateEditor.above(editor, {
        at: end,
        match: matchInternalBlock,
      });

      if (startItem && endItem && Path.compare(startItem[1], endItem[1]) !== 0) {
        const deletableItem = SlateEditor.above(editor, {
          at: start,
          match: matchBlockToDelete,
        });
        if (deletableItem) {
          Transforms.removeNodes(editor, { at: deletableItem[1] });
          e.preventDefault();
        }
      }
    } else if (editor.selection && Range.isCollapsed(editor.selection)) {
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
  if (e.key === 'Delete') {
    deleteOrBackspaceBlock(editor, e, 'after');
  }
};

export const backspaceBlockKeyDown = (editor: SlateEditor, e: KeyboardEvent) => {
  if (e.key === 'Backspace') {
    deleteOrBackspaceBlock(editor, e, 'before');
  }
};
