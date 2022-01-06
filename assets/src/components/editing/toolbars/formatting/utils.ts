import { ReactEditor } from 'slate-react';
import { Editor, Range } from 'slate';

export function shouldShowFormattingToolbar(editor: Editor): boolean {
  const { selection } = editor;

  return !!selection && ReactEditor.isFocused(editor) && !Range.isCollapsed(selection);
}
