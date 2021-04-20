import * as ContentModel from 'data/content/model';
import { Transforms, Editor } from 'slate';
import { Command, CommandDesc } from 'components/editing/commands/interfaces';
import { isActive } from '../utils';

const command: Command = {
  execute: (context, editor, params) => {
    const selection = editor.selection;
    if (!selection) return;

    if (isActive(editor, 'a')) {
      return Transforms.unwrapNodes(editor, { match: (node) => node.type === 'a' });
    }

    const href = Editor.string(editor, selection);
    Transforms.wrapNodes(editor, ContentModel.link(href), { split: true });
  },
  precondition: (editor) => {
    return !isActive(editor, ['code']);
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'insert_link',
  description: () => 'Link (⌘L)',
  command,
  active: (e) => isActive(e, 'a'),
};
