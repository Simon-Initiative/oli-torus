import { Editor, Element, Node, Point, Range } from 'slate';

const isElementType = (type: string, types: string[]) => types.indexOf(type) > -1;

export const withTables = (editor: Editor) => {
  const { deleteBackward, deleteForward, deleteFragment } = editor;

  editor.deleteFragment = () => {
    const { selection } = editor;
    if (selection) {
      const [start, end] = Range.edges(selection);

      // Prevent deletion if start or end of selection is inside a table.
      const isInsideTable = (n: Node) =>
        Element.isElement(n) && isElementType(n.type, ['tr', 'th', 'td', 'tc']);
      const [...startNodes] = Editor.nodes(editor, { at: start, match: isInsideTable });
      const [...endNodes] = Editor.nodes(editor, { at: end, match: isInsideTable });
      if (startNodes.length > 0 || endNodes.length > 0) {
        return;
      }
    }

    deleteFragment();
  };

  editor.deleteBackward = (unit) => {
    const { selection } = editor;

    if (selection && Range.isCollapsed(selection)) {
      const [cell] = Editor.nodes(editor, {
        match: (n) => Element.isElement(n) && isElementType(n.type, ['td', 'tc']),
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
        match: (n) => Element.isElement(n) && isElementType(n.type, ['td', 'tc']),
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
