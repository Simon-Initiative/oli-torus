import { ReactEditor } from 'slate-react';
import { Range } from 'slate';

export function shouldShowFormattingToolbar(editor: ReactEditor) {
  const { selection } = editor;

  return !!selection && ReactEditor.isFocused(editor) && !Range.isCollapsed(selection);
}
