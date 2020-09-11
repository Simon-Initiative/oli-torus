import { Transforms } from 'slate';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from 'components/editing/commands/interfaces';
import { isActive } from '../utils';

const command: Command = {
  execute: (context, editor) => {
    Transforms.insertNodes(editor, ContentModel.code());
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
