import { Transforms, Editor } from 'slate';
import { isTopLevel, isActive } from 'components/editing/utils';
import { CommandDesc, Command } from 'components/editing/commands/interfaces';

const command: Command = {
  execute: (context, editor) => {

    Editor.withoutNormalizing(editor, () => {
      const active = isActive(editor, 'blockquote');
      if (active) {
        return Transforms.unwrapNodes(editor, { match: n => n.type === 'blockquote' });
      }

      Transforms.setNodes(editor, { type: 'p' });
      Transforms.wrapNodes(editor, { type: 'blockquote', children: [] });
    });
  },
  precondition: (editor) => {
    return isTopLevel(editor) && isActive(editor, ['p'])
      || isActive(editor, ['blockquote']);
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'format_quote',
  description: () => 'Quote',
  command,
  active: e => isActive(e, 'blockquote'),
};
