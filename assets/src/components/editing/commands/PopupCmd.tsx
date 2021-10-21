import { Command, CommandDesc } from 'components/editing/commands/interfaces';
import * as ContentModel from 'data/content/model';
import { Transforms } from 'slate';
import { isActive } from '../utils';

const command: Command = {
  execute: (_context, editor, _params) => {
    const selection = editor.selection;
    if (!selection) return;

    if (isActive(editor, 'popup')) {
      return Transforms.unwrapNodes(editor, { match: (node) => node.type === 'popup' });
    }

    // const anchorText = Editor.string(editor, selection);
    Transforms.wrapNodes(editor, ContentModel.popup(), { split: true });
  },
  precondition: (_editor) => {
    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'outbound',
  description: () => 'Popup',
  command,
  active: (e) => isActive(e, 'popup'),
};
