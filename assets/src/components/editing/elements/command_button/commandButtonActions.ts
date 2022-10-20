import { Transforms, Element } from 'slate';
import { isActive } from '../../slateUtils';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from '../commands/commandFactories';

export const insertCommandButton = createButtonCommandDesc({
  icon: 'smart_button',
  description: 'Command Button',
  execute: (_context, editor, _params) => {
    const selection = editor.selection;
    if (!selection) return;

    if (isActive(editor, 'command_button')) {
      return Transforms.unwrapNodes(editor, {
        match: (node) => Element.isElement(node) && node.type === 'command_button',
      });
    }

    Transforms.wrapNodes(editor, Model.commandButton(), { split: true });
  },
  precondition: (editor) => !isActive(editor, ['code']),
  active: (e) => isActive(e, 'command_button'),
});
