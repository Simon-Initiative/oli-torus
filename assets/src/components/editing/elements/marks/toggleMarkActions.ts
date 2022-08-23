import { isActive, isMarkActive } from 'components/editing/slateUtils';
import { Command } from 'components/editing/elements/commands/interfaces';
import { Mark } from 'data/content/model/text';
import { Editor } from 'slate';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { citationCmdDesc } from 'components/editing/elements/cite/CiteCmd';

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

export const boldDesc = toggleFormat({ icon: 'format_bold', mark: 'strong', description: 'Bold' });

export const italicDesc = toggleFormat({
  icon: 'format_italic',
  mark: 'em',
  description: 'Italic',
});

export const underLineDesc = toggleFormat({
  icon: 'format_underlined',
  mark: 'underline',
  description: 'Underline',
});

export const strikethroughDesc = toggleFormat({
  icon: 'strikethrough_s',
  mark: 'strikethrough',
  description: 'Strikethrough',
});

export const subscriptDesc = toggleFormat({
  icon: 'subscript',
  mark: 'sub',
  description: 'Subscript',
  precondition: (editor) => !isActive(editor, ['code']),
});

export const superscriptDesc = toggleFormat({
  icon: 'superscript',
  mark: 'sup',
  description: 'Superscript',
  precondition: (editor) => !isActive(editor, ['code']),
});

export const inlineCodeDesc = toggleFormat({
  icon: 'code',
  mark: 'code',
  description: 'Code',
  precondition: (editor) => !isActive(editor, ['code']),
});

export const termDesc = toggleFormat({
  icon: 'menu_book',
  mark: 'term',
  description: 'Term',
  precondition: (editor) => !isActive(editor, ['term']),
});

export const additionalFormattingOptions = [
  underLineDesc,
  strikethroughDesc,
  subscriptDesc,
  superscriptDesc,
  termDesc,
  citationCmdDesc,
];
