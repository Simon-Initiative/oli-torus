import { Transforms, Editor, Element } from 'slate';
import { Command, CommandDesc } from 'components/editing/nodes/commands/interfaces';
import { isActive } from '../../utils';
import { Model } from 'data/content/model/nodes/factories';

const command: Command = {
  execute: (_context, editor, _params) => {
    const selection = editor.selection;
    if (!selection) return;

    if (isActive(editor, 'a')) {
      return Transforms.unwrapNodes(editor, {
        match: (node) => Element.isElement(node) && node.type === 'a',
      });
    }

    const href = Editor.string(editor, selection);
    Transforms.wrapNodes(editor, Model.link(href), { split: true });
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
