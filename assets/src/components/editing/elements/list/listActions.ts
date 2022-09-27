import { handleOutdent, handleIndent } from 'components/editing/editor/handlers/lists';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Command, CommandDescription } from 'components/editing/elements/commands/interfaces';
import { switchType } from 'components/editing/elements/commands/toggleTextTypes';
import { isActive, isPropActive, isTopLevel } from 'components/editing/slateUtils';

import { Transforms, Editor, Element } from 'slate';
import guid from 'utils/guid';
import {
  OrderedListStyle,
  OrderedListStyles,
  UnorderdListStyles,
  UnorderedListStyle,
} from '../../../../data/content/model/elements/types';

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

        // Transforms.setNodes(editor, { type: 'p' });
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

const listStyleLabels: Record<OrderedListStyle | UnorderedListStyle, string> = {
  none: 'No Bullet',
  decimal: 'Decimal - 1',
  'decimal-leading-zero': 'Decimal w/ Zero - 01',
  'lower-roman': 'Lower Roman - i',
  'upper-roman': 'Upper Roman - I',
  'lower-alpha': 'Lower Alpha - a',
  'upper-alpha': 'Upper Alpha - A',
  // 'lower-latin': 'Lower Latin - a', // These are the same as -alpha, no need to have both in the menu
  // 'upper-latin': 'Upper Latin - A', // but we do support rendering both for legacy content.
  disc: 'Disc - •',
  circle: 'Circle - ○',
  square: 'Square - ■',
};

export const unorderedListStyleCommands = UnorderdListStyles.map((styleType: string) =>
  createButtonCommandDesc({
    icon: 'list_alt',
    description: listStyleLabels[styleType],
    active: (editor) => isPropActive(editor, 'ul', { style: styleType }),
    execute: (_ctx, editor) => {
      const [, at] = [...Editor.nodes(editor)][1];
      Transforms.setNodes(
        editor,
        { style: styleType },
        { at, match: (e) => Element.isElement(e) && isList(e), mode: 'all' },
      );
    },
  }),
);

// The two -latin options don't need menu options since they are the same as -alpha
const notLatinOption = (styleType: string) => styleType.indexOf('latin') === -1;

export const orderedListStyleCommands = OrderedListStyles.filter(notLatinOption).map(
  (styleType: string) =>
    createButtonCommandDesc({
      icon: 'list_alt',
      description: listStyleLabels[styleType],
      active: (editor) => isPropActive(editor, 'ol', { style: styleType }),
      execute: (_ctx, editor) => {
        const [, at] = [...Editor.nodes(editor)][1];
        Transforms.setNodes(
          editor,
          { style: styleType },
          { at, match: (e) => Element.isElement(e) && isList(e), mode: 'all' },
        );
      },
    }),
);

export const listSettingButtonGroups = [
  [
    createButtonCommandDesc({
      icon: 'format_list_bulleted',
      description: 'Unordered List',
      active: (editor) => isActive(editor, ['ul']),
      execute: (_ctx, editor) => {
        const [, at] = [...Editor.nodes(editor)][1];
        Transforms.setNodes(
          editor,
          { type: 'ul', style: undefined },
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
          { type: 'ol', style: undefined },
          { at, match: (e) => Element.isElement(e) && e.type === 'ul', mode: 'all' },
        );
      },
    }),
  ],
  [
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
  ],
];

const isList = (e: Element): boolean => ['ul', 'ol'].indexOf(e.type) !== -1;

function isActiveList(editor: Editor) {
  return isActive(editor, ['ul', 'ol']);
}
