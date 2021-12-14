import { Transforms } from 'slate';
import { Command, CommandDesc } from 'components/editing/commands/interfaces';
import { isActive } from '../utils';
import { code } from 'data/content/model/elements/factories';

const command: Command = {
  execute: (_context, editor) => {
    if (!editor.selection) return;
    Transforms.insertNodes(editor, code(), { at: editor.selection });
  },
  precondition: (editor) => {
    return !isActive(editor, 'table');
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'code',
  description: () => 'Code (```)',
  command,
};
