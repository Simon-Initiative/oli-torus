import { Transforms } from 'slate';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from 'components/editor/commands/interfaces';

const command: Command = {
  execute: (context, editor) => {
    Transforms.insertNodes(editor, ContentModel.code());
  },
  precondition: (editor) => {
    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'code',
  description: () => 'Code',
  command,
};
