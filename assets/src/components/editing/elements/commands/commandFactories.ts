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
  tooltip?: string;
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
  tooltip,
  precondition,
}: CommandWrapperProps): CommandDescription {
  return {
    type: 'CommandDesc',
    category,
    icon: () => icon,
    tooltip: tooltip,
    description: () => description,
    ...(active ? { active } : {}),
    command: {
      execute: (context, editor: Editor) => execute(context, editor),
      ...(precondition ? { precondition } : { precondition: (_editor) => true }),
    },
  };
}
