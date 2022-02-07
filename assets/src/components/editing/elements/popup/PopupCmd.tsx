import { Command, CommandDescription } from 'components/editing/elements/commands/interfaces';
import { Model } from 'data/content/model/elements/factories';
import { Element, Transforms } from 'slate';
import { isActive } from '../../utils';

const command: Command = {
  execute: (_context, editor, _params) => {
    const selection = editor.selection;
    if (!selection) return;

    if (isActive(editor, 'popup')) {
      return Transforms.unwrapNodes(editor, {
        match: (node) => Element.isElement(node) && node.type === 'popup',
      });
    }

    Transforms.wrapNodes(editor, Model.popup(), { split: true });
  },
  precondition: (_editor) => {
    return true;
  },
};

export const popupCmdDesc: CommandDescription = {
  type: 'CommandDesc',
  icon: () => 'outbound',
  description: () => 'Popup Content',
  command,
  active: (e) => isActive(e, 'popup'),
};
