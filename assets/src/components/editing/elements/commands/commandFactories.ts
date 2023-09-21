import { Editor } from 'slate';
import { Mark } from 'data/content/model/text';
import { Command, CommandCategories, CommandDescription } from './interfaces';

interface CommandWrapperProps {
  icon?: JSX.Element;
  description: string;
  category?: CommandCategories;
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
  category,
  precondition,
}: CommandWrapperProps): CommandDescription {
  return {
    type: 'CommandDesc',
    category,
    icon: () => icon,
    description: () => description,
    ...(active ? { active } : {}),
    command: {
      execute: (context, editor: Editor) => execute(context, editor),
      ...(precondition ? { precondition } : { precondition: (_editor) => true }),
    },
  };
}
