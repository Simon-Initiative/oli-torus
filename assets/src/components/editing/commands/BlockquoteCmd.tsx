import { Transforms, Editor, Element } from 'slate';
import { isTopLevel, isActive } from 'components/editing/utils';
import { CommandDesc, Command } from 'components/editing/commands/interfaces';
import guid from 'utils/guid';

const command: Command = {
  execute: (context, editor) => {
    Editor.withoutNormalizing(editor, () => {
      const active = isActive(editor, 'blockquote');
      if (active) {
        return Transforms.unwrapNodes(editor, {
          match: (n) => Element.isElement(n) && n.type === 'blockquote',
        });
      }

      Transforms.setNodes(editor, { type: 'p' });
      Transforms.wrapNodes(editor, { type: 'blockquote', id: guid(), children: [] });
    });
  },
  precondition: (editor) => {
    return (isTopLevel(editor) && isActive(editor, ['p'])) || isActive(editor, ['blockquote']);
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'format_quote',
  description: () => 'Quote (> )',
  command,
  active: (e) => isActive(e, 'blockquote'),
};
