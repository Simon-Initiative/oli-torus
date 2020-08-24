import { ReactEditor } from 'slate-react';
import { Transforms, Editor } from 'slate';
import { isActiveQuote, isTopLevel, isActive } from 'components/editor/utils';
import { CommandDesc, Command } from 'components/editor/commands/interfaces';

const command: Command = {
  execute: (context, editor: ReactEditor) => {

    Editor.withoutNormalizing(editor, () => {
      const isActive = isActiveQuote(editor);
      if (isActive) {
        return Transforms.unwrapNodes(editor, { match: n => n.type === 'blockquote' });
      }

      Transforms.setNodes(editor, { type: 'p' });
      Transforms.wrapNodes(editor, { type: 'blockquote', children: [] });
    });
  },
  precondition: (editor: ReactEditor) => {
    return isTopLevel(editor) && isActive(editor, ['p'])
      || isActive(editor, ['blockquote']);
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'format_quote',
  description: () => 'Quote',
  command,
  active: isActiveQuote,
};
