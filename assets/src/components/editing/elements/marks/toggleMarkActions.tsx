import React from 'react';
import { Editor } from 'slate';
import { citationCmdDesc } from 'components/editing/elements/cite/CiteCmd';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Command, CommandCategories } from 'components/editing/elements/commands/interfaces';
import { isActive, isMarkActive } from 'components/editing/slateUtils';
import { Mark } from 'data/content/model/text';

export function toggleMark(editor: Editor, mark: Mark) {
  if (isMarkActive(editor, mark)) Editor.removeMark(editor, mark);
  else Editor.addMark(editor, mark, true);
}

export const toggleFormat = (attrs: {
  icon: JSX.Element;
  description: string;
  mark: Mark;
  category: CommandCategories;
  precondition?: Command['precondition'];
  execute?: Command['execute'];
}) => {
  const defaultExecute: Command['execute'] = (context, editor) => toggleMark(editor, attrs.mark);

  return createButtonCommandDesc({
    ...attrs,
    execute: attrs.execute || defaultExecute,
    active: (editor) => isMarkActive(editor, attrs.mark),
  });
};

export const boldDesc = toggleFormat({
  icon: <i className="fa-solid fa-bold"></i>,
  category: 'Formatting',
  mark: 'strong',
  description: 'Bold',
});

export const italicDesc = toggleFormat({
  icon: <i className="fa-solid fa-italic"></i>,
  category: 'Formatting',
  mark: 'em',
  description: 'Italic',
});

export const underLineDesc = toggleFormat({
  icon: <i className="fa-solid fa-underline"></i>,
  category: 'Formatting',
  mark: 'underline',
  description: 'Underline',
});

export const strikethroughDesc = toggleFormat({
  icon: <i className="fa-solid fa-strikethrough"></i>,
  category: 'Formatting',
  mark: 'strikethrough',
  description: 'Strikethrough',
});

export const subscriptDesc = toggleFormat({
  icon: <i className="fa-solid fa-subscript"></i>,
  mark: 'sub',
  category: 'Formatting',
  description: 'Subscript',
  precondition: (editor) => !isActive(editor, ['code']),
  execute: (context, editor) => {
    Editor.removeMark(editor, 'doublesub'); // We really don't want both double & single subscript at the same time.
    toggleMark(editor, 'sub');
  },
});

export const superscriptDesc = toggleFormat({
  icon: <i className="fa-solid fa-superscript"></i>,
  category: 'Formatting',
  mark: 'sup',
  description: 'Superscript',
  precondition: (editor) => !isActive(editor, ['code']),
});

export const doublesubscriptDesc = toggleFormat({
  icon: <i className="fa-solid fa-subscript"></i>,
  category: 'Formatting',
  mark: 'doublesub',
  description: 'Double Subscript',
  precondition: (editor) => !isActive(editor, ['code']),
  execute: (context, editor) => {
    Editor.removeMark(editor, 'sub');
    toggleMark(editor, 'doublesub');
  },
});

export const inlineCodeDesc = toggleFormat({
  icon: <i className="fa-solid fa-code"></i>,
  category: 'Formatting',
  mark: 'code',
  description: 'Code',
  precondition: (editor) => !isActive(editor, ['code']),
});

export const termDesc = toggleFormat({
  icon: <i className="fa-solid fa-book-open"></i>,
  category: 'Formatting',
  mark: 'term',
  description: 'Term',
  precondition: (editor) => !isActive(editor, ['term']),
});

export const deemphasisDesc = toggleFormat({
  icon: <i className="fa-solid fa-bold line-through"></i>,
  category: 'Formatting',
  mark: 'deemphasis',
  description: 'Deemphasis',
  precondition: (editor) => !isActive(editor, ['term']),
});

export const additionalFormattingOptions = [
  underLineDesc,
  strikethroughDesc,
  subscriptDesc,
  doublesubscriptDesc,
  superscriptDesc,
  termDesc,
  citationCmdDesc,
  deemphasisDesc,
];
