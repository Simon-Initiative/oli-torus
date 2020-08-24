import { ReactEditor } from 'slate-react';
import { Transforms, Editor as SlateEditor } from 'slate';
import { CommandContext, Command, CommandDesc } from 'components/editor/commands/interfaces';
import { isActiveList, isActive, isTopLevel } from 'components/editor/utils';

const listCommandMaker = (listType: string): Command => {
  return {
    execute: (context: CommandContext, editor: ReactEditor) => {
      SlateEditor.withoutNormalizing(editor, () => {

        const active = isActiveList(editor);

        Transforms.unwrapNodes(editor, {
          match: n => n.type === 'ul' || n.type === 'ol',
          split: true,
          mode: 'all',
        });

        Transforms.setNodes(editor, {
          type: active ? 'p' : 'li',
        });

        if (!active) {
          const block = { type: listType, children: [] };
          Transforms.wrapNodes(editor, block);
        }
      });
    },
    precondition: (editor: ReactEditor) => {
      if (isActiveList(editor)) {
        return isActive(editor, [listType]);
      }
      return isTopLevel(editor) && isActive(editor, ['p']);
    },
  };
};

const ulCommand: Command = listCommandMaker('ul');
const olCommand: Command = listCommandMaker('ol');

export const ulCommandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'format_list_bulleted',
  description: () => 'Unordered List',
  command: ulCommand,
  active: editor => isActive(editor, ['ul']),
};

export const olCommandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'format_list_numbered',
  description: () => 'Ordered List',
  command: olCommand,
  active: editor => isActive(editor, ['ol']),
};
