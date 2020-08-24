import { Editor } from 'slate';
import { Mark } from 'data/content/model';
import { ReactEditor } from 'slate-react';
import { CommandDesc, CommandContext, Command } from './interfaces';
import { marksInEntireSelection } from '../utils';

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

export function createToggleFormatCommand(icon: string, mark: Mark, description: string) {
  return createCommandDesc(
    icon,
    description,
    (context, editor) => toggleMark(editor, mark),
    editor => marksInEntireSelection(editor).indexOf(mark) !== -1,
  );
}

export function createButtonCommandDesc(
  icon: string,
  description: string,
  execute: Command['execute'],
  active: CommandDesc['active'] = undefined) {
  return createCommandDesc(
    icon,
    description,
    execute,
    active,
  );
}

function createCommandDesc(
  icon: string,
  description: string,
  execute: Command['execute'],
  active: CommandDesc['active'] = undefined): CommandDesc {
  return {
    type: 'CommandDesc',
    icon: () => icon,
    description: () => description,
    ...(active ? { active } : {}),
    command: {
      execute: (context, editor: ReactEditor) => execute(context, editor),
      precondition: editor => true,
    },
  };
}
