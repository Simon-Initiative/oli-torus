import { ReactEditor } from 'slate-react';
import { Editor, Range, Text } from 'slate';

export function shouldShowFixedToolbar(editor: ReactEditor) {
  const { selection } = editor;

  if (!selection) return false;

  // True if the cursor is in a paragraph at the toplevel with no content
  const isCursorAtEmptyLine = () => {
    const nodes = Array.from(Editor.nodes(editor, { at: selection }));
    if (nodes.length !== 3) {
      return false;
    }
    const [[first], [second], [third]] = nodes;
    return Editor.isEditor(first) &&
      second.type === 'p' &&
      Text.isText(third) && third.text === '';
  };

  return ReactEditor.isFocused(editor) &&
    Range.isCollapsed(selection);
    // isCursorAtEmptyLine();
}
