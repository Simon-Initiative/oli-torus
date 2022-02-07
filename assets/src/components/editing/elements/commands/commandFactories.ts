import { Editor } from 'slate';
import { CommandDescription, Command } from './interfaces';
import { Mark } from 'data/content/model/text';

interface CommandWrapperProps {
  icon: string;
  description: string;
  execute: Command['execute'];
  mark?: Mark;
  active?: CommandDescription['active'];
  precondition?: Command['precondition'];
}

export function createButtonCommandDesc(attrs: CommandWrapperProps) {
  return createCommandDesc(attrs);
}

function createCommandDesc({
  icon,
  description,
  execute,
  active,
  precondition,
}: CommandWrapperProps): CommandDescription {
  return {
    type: 'CommandDesc',
    icon: () => icon,
    description: () => description,
    ...(active ? { active } : {}),
    command: {
      execute: (context, editor: Editor) => execute(context, editor),
      ...(precondition ? { precondition } : { precondition: (_editor) => true }),
    },
  };
}
