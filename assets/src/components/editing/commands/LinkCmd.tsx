import { Transforms, Editor, Element } from 'slate';
import { isActive } from '../utils';
import { link } from 'data/content/model/elements/factories';
import { ButtonCommand } from 'components/editing/toolbar/interfaces';
import { toolbarButtonDesc } from 'components/editing/toolbar/commands';

const command: ButtonCommand = {
  execute: (_context, editor, _params) => {
    const selection = editor.selection;
    if (!selection) return;

    if (isActive(editor, 'a')) {
      return Transforms.unwrapNodes(editor, {
        match: (node) => Element.isElement(node) && node.type === 'a',
      });
    }

    const href = Editor.string(editor, selection);
    Transforms.wrapNodes(editor, link(href), { split: true });
  },
  precondition: (editor) => {
    return !isActive(editor, ['code']);
  },
};

export const commandDesc = toolbarButtonDesc({
  icon: () => 'insert_link',
  description: () => 'Link (⌘L)',
  ...command,
  active: (e) => isActive(e, 'a'),
});
