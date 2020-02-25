import { Editor, Transforms, Text } from 'slate';
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

function toggleMark(editor: ReactEditor, mark: Mark) {
  const isActive = isMarkActive(editor, mark);

  Transforms.setNodes(
    editor,
    { [mark]: isActive ? null : true },
    { match: n => Text.isText(n), split: true },
  );
}

export function createToggleFormatCommand(icon: string, mark: Mark, description: string)
  : CommandDesc {
  return {
    type: 'CommandDesc',
    icon,
    description,
    command: {
      execute: (editor: ReactEditor) => toggleMark(editor, mark),
      precondition: (editor: ReactEditor) => {
        return true;
      },
    },
  };
}
