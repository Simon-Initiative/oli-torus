import { Transforms, Editor as SlateEditor } from 'slate';
import { Command, CommandDesc } from 'components/editing/commands/interfaces';
import { isActiveList, isActive, isTopLevel } from 'components/editing/utils';

const listCommandMaker = (listType: string): Command => {
  return {
    execute: (context, editor) => {
      SlateEditor.withoutNormalizing(editor, () => {

        const active = isActiveList(editor);

        // Not a list, create one
        if (!active) {
          Transforms.setNodes(editor, { type: 'li' });
          Transforms.wrapNodes(editor, { type: listType, children: [] });
          return;
        }

        // Wrong type of list, toggle
        if (!isActive(editor, [listType])) {
          Transforms.setNodes(editor, { type: listType }, {
            match: n => n.type === (listType === 'ol' ? 'ul' : 'ol'),
            mode: 'all',
          });
          return;
        }

        // Is a list, unwrap it
        Transforms.unwrapNodes(editor, {
          match: n => n.type === 'ul' || n.type === 'ol',
          split: true,
          mode: 'all',
        });

        Transforms.setNodes(editor, { type: 'p' });
      });
    },
    precondition: (editor) => {
      return isTopLevel(editor) && isActive(editor, ['p'])
        || isActiveList(editor);
    },
  };
};

export const ulCommandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'format_list_bulleted',
  description: () => 'Unordered List (* )',
  command: listCommandMaker('ul'),
  active: editor => isActive(editor, ['ul']),
};

export const olCommandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'format_list_numbered',
  description: () => 'Ordered List (1. )',
  command: listCommandMaker('ol'),
  active: editor => isActive(editor, ['ol']),
};
