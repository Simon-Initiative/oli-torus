import { Editor } from 'slate';
import { Mark } from 'data/content/model';
import { ReactEditor } from 'slate-react';
import { CommandDesc } from './interfaces';

function isMarkActive(editor: ReactEditor, mark: Mark): boolean {

  const [match] = Editor.nodes(editor, {
    match: n => n[mark] === true,
    universal: true,
  });

  return !!match;
}

export function toggleMark(editor: ReactEditor, mark: Mark) {
  const isActive = isMarkActive(editor, mark);

  if (isActive) {
    Editor.removeMark(editor, mark);
  } else {
    Editor.addMark(editor, mark, true);
  }
}

export function createToggleFormatCommand(icon: string, mark: Mark, description: string)
  : CommandDesc {
  return {
    type: 'CommandDesc',
    icon: () => icon,
    description: () => description,
    active: marks => marks.indexOf(mark) !== -1,
    command: {
      execute: (context, editor: ReactEditor) => toggleMark(editor, mark),
      precondition: (editor: ReactEditor) => {
        return true;
      },
    },
  };
}
