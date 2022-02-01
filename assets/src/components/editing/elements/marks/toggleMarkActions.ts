import { popupCmdDesc } from 'components/editing/elements/popup/PopupCmd';
import { isActive, isMarkActive } from 'components/editing/utils';
import { Command } from 'components/editing/elements/commands/interfaces';
import { Mark } from 'data/content/model/text';
import { Editor } from 'slate';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';

export function toggleMark(editor: Editor, mark: Mark) {
  if (isMarkActive(editor, mark)) Editor.removeMark(editor, mark);
  else Editor.addMark(editor, mark, true);
}

export const toggleFormat = (attrs: {
  icon: string;
  description: string;
  mark: Mark;
  precondition?: Command['precondition'];
}) =>
  createButtonCommandDesc({
    ...attrs,
    execute: (context, editor) => toggleMark(editor, attrs.mark),
    active: (editor) => isMarkActive(editor, attrs.mark),
  });

const underLineDesc = toggleFormat({
  icon: 'format_underlined',
  mark: 'underline',
  description: 'Underline',
});

const strikethroughDesc = toggleFormat({
  icon: 'strikethrough_s',
  mark: 'strikethrough',
  description: 'Strikethrough',
});

const subscriptDesc = toggleFormat({
  icon: 'subscript',
  mark: 'sub',
  description: 'Subscript',
  precondition: (editor) => !isActive(editor, ['code']),
});

const superscriptDesc = toggleFormat({
  icon: 'superscript',
  mark: 'sup',
  description: 'Superscript',
  precondition: (editor) => !isActive(editor, ['code']),
});

const inlineCodeDesc = toggleFormat({
  icon: 'code',
  mark: 'code',
  description: 'Code',
  precondition: (editor) => !isActive(editor, ['code']),
});

export const additionalFormattingOptions = [
  underLineDesc,
  strikethroughDesc,
  inlineCodeDesc,
  subscriptDesc,
  superscriptDesc,
  popupCmdDesc,
];
