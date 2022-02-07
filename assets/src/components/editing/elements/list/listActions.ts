import { handleOutdent, handleIndent } from 'components/editing/editor/handlers/lists';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Command, CommandDescription } from 'components/editing/elements/commands/interfaces';
import { switchType } from 'components/editing/elements/commands/toggleTextTypes';
import { isActive, isActiveList, isTopLevel } from 'components/editing/utils';
import { Transforms, Editor, Element } from 'slate';
import guid from 'utils/guid';

const listCommandMaker = (listType: 'ul' | 'ol'): Command => {
  return {
    execute: (context, editor) => {
      Editor.withoutNormalizing(editor, () => {
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
    },
    precondition: (editor) => {
      return (isTopLevel(editor) && isActive(editor, ['p'])) || isActiveList(editor);
    },
  };
};

export const toggleList = createButtonCommandDesc({
  icon: 'format_list_bulleted',
  description: 'List',
  active: (editor) => isActive(editor, ['ul', 'ol']),
  execute: (_ctx, editor) => switchType(editor, 'ul'),
});

export const toggleUnorderedList: CommandDescription = {
  type: 'CommandDesc',
  icon: () => 'format_list_bulleted',
  description: () => 'Unordered List',
  command: listCommandMaker('ul'),
  active: (editor) => isActive(editor, ['ul']),
};

export const toggleOrderedList: CommandDescription = {
  type: 'CommandDesc',
  icon: () => 'format_list_numbered',
  description: () => 'Ordered List',
  command: listCommandMaker('ol'),
  active: (editor) => isActive(editor, ['ol']),
};

export const listSettings = [
  createButtonCommandDesc({
    icon: 'format_list_bulleted',
    description: 'Unordered List',
    active: (editor) => isActive(editor, ['ul']),
    execute: (_ctx, editor) => {
      const [, at] = [...Editor.nodes(editor)][1];
      Transforms.setNodes(
        editor,
        { type: 'ul' },
        { at, match: (e) => Element.isElement(e) && e.type === 'ol', mode: 'all' },
      );
    },
  }),
  createButtonCommandDesc({
    icon: 'format_list_numbered',
    description: 'Ordered List',
    active: (editor) => isActive(editor, ['ol']),
    execute: (_ctx, editor) => {
      const [, at] = [...Editor.nodes(editor)][1];
      Transforms.setNodes(
        editor,
        { type: 'ol' },
        { at, match: (e) => Element.isElement(e) && e.type === 'ul', mode: 'all' },
      );
    },
  }),
  createButtonCommandDesc({
    icon: 'format_indent_decrease',
    description: 'Outdent',
    active: (_e) => false,
    execute: (_ctx, editor) => handleOutdent(editor),
  }),
  createButtonCommandDesc({
    icon: 'format_indent_increase',
    description: 'Indent',
    active: (_e) => false,
    execute: (_ctx, editor) => handleIndent(editor),
  }),
];
