import { Range, Editor, Point, Path } from 'slate';

export const withTables = (editor: Editor) => {
  const { deleteBackward, deleteForward, deleteFragment } = editor;

  editor.deleteFragment = () => {
    const { selection } = editor;
    if (selection) {
      const [...blocks] = Editor.nodes(editor, {
        match: n => ['tr', 'th', 'td'].indexOf(n.type as string) > -1,
        mode: 'lowest',
      });
      if (blocks.length > 0) {

        const [start, end] = Range.edges(selection);
        const startBlock = Editor.above(editor, {
          match: n => Editor.isBlock(editor, n),
          at: start,
        });
        const endBlock = Editor.above(editor, {
          match: n => Editor.isBlock(editor, n),
          at: end,
        });

        const isAcrossBlocks =
          startBlock && endBlock && !Path.equals(startBlock[1], endBlock[1]);

        if (isAcrossBlocks) {
          return;
        }
      }
    }

    deleteFragment();
  };

  editor.deleteBackward = (unit) => {
    const { selection } = editor;

    if (selection && Range.isCollapsed(selection)) {
      const [cell] = Editor.nodes(editor, {
        match: n => n.type === 'td',
      });

      if (cell) {
        const [, cellPath] = cell;
        const start = Editor.start(editor, cellPath);

        if (Point.equals(selection.anchor, start)) {
          return;
        }
      }
    }

    deleteBackward(unit);
  };

  editor.deleteForward = (unit) => {
    const { selection } = editor;

    if (selection && Range.isCollapsed(selection)) {
      const [cell] = Editor.nodes(editor, {
        match: n => n.type === 'td',
      });

      if (cell) {
        const [, cellPath] = cell;
        const end = Editor.end(editor, cellPath);

        if (Point.equals(selection.anchor, end)) {
          return;
        }
      }
    }

    deleteForward(unit);
  };

  return editor;
};
