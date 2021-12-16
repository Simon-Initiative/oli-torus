import { Transforms, Editor as SlateEditor, Element } from 'slate';
import { isActiveList, isActive, isTopLevel } from 'components/editing/utils';
import guid from 'utils/guid';
import { ButtonCommand } from 'components/editing/toolbar/interfaces';
import { toolbarButtonDesc } from 'components/editing/toolbar/commands';

const execute =
  (listType: 'ul' | 'ol'): ButtonCommand['execute'] =>
  (_context, editor) => {
    SlateEditor.withoutNormalizing(editor, () => {
      const active = isActiveList(editor);

      // Not a list, create one
      if (!active) {
        Transforms.setNodes(editor, { type: 'li' });
        Transforms.wrapNodes(editor, { type: listType, id: guid(), children: [] });
        return;
      }

      // Wrong type of list, toggle
      if (!isActive(editor, [listType])) {
        Transforms.setNodes(
          editor,
          { type: listType },
          {
            match: (n) => Element.isElement(n) && n.type === (listType === 'ol' ? 'ul' : 'ol'),
            mode: 'all',
          },
        );
        return;
      }

      // Is a list, unwrap it
      Transforms.unwrapNodes(editor, {
        match: (n) => Element.isElement(n) && (n.type === 'ul' || n.type === 'ol'),
        split: true,
        mode: 'all',
      });

      Transforms.setNodes(editor, { type: 'p' });
    });
  };

const precondition: ButtonCommand['precondition'] = (editor) =>
  (isTopLevel(editor) && isActive(editor, ['p'])) || isActiveList(editor);

export const ulCommandDesc = toolbarButtonDesc({
  icon: () => 'format_list_bulleted',
  description: () => 'Unordered List (* )',
  execute: execute('ul'),
  precondition,
  active: (editor) => isActive(editor, ['ul']),
});

export const olCommandDesc = toolbarButtonDesc({
  icon: () => 'format_list_numbered',
  description: () => 'Ordered List (1. )',
  execute: execute('ol'),
  precondition,
  active: (editor) => isActive(editor, ['ol']),
});
