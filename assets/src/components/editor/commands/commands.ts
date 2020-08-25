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

export function createToggleFormatCommand(attrs: any) {
  return createCommandDesc({
    ...attrs,
    execute: (context, editor) => toggleMark(editor, attrs.mark),
    active: editor => marksInEntireSelection(editor).indexOf(attrs.mark) !== -1,
  });
}

export function createButtonCommandDesc(attrs: any) {
  return createCommandDesc(attrs);
}

function createCommandDesc({ icon, description, execute, active, precondition }:
  {
    icon: string,
    mark: Mark,
    description: string,
    execute: Command['execute'],
    active?: CommandDesc['active'],
    precondition?: Command['precondition'],
  }): CommandDesc {
  return {
    type: 'CommandDesc',
    icon: () => icon,
    description: () => description,
    ...(active ? { active } : {}),
    command: {
      execute: (context, editor: ReactEditor) => execute(context, editor),
      ...(precondition ? { precondition } : { precondition: editor => true }),
    },
  };
}
