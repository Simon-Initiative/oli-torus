import { Transforms, Editor as SlateEditor } from 'slate';
import { Command, CommandDesc } from 'components/editor/commands/interfaces';
import { isActiveList, isActive, isTopLevel } from 'components/editor/utils';

const listCommandMaker = (listType: string): Command => {
  return {
    execute: (context, editor) => {
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
    precondition: (editor) => {
      if (isActiveList(editor)) {
        return isActive(editor, [listType]) && !isActive(editor, ['code']);
      }
      return (isTopLevel(editor) || isActive(editor, ['table'])) && isActive(editor, ['p']);
    },
  };
};

export const ulCommandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'format_list_bulleted',
  description: () => 'Unordered List',
  command: listCommandMaker('ul'),
  active: editor => isActive(editor, ['ul']),
};

export const olCommandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'format_list_numbered',
  description: () => 'Ordered List',
  command: listCommandMaker('ol'),
  active: editor => isActive(editor, ['ol']),
};
