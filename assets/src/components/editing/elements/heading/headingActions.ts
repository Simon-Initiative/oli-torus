import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { switchType } from 'components/editing/elements/commands/toggleTextTypes';
import { getNearestBlock, isActive, isTopLevel } from 'components/editing/utils';
import { Editor, Element, Transforms } from 'slate';

export const toggleHeading = createButtonCommandDesc({
  icon: 'title',
  description: 'Heading',
  active: (editor) => isActive(editor, ['h1', 'h2']),
  execute: (_ctx, editor) => switchType(editor, 'h2'),
});

const parentTextTypes = {
  p: true,
  h1: true,
  // h2 through h6 are for legacy support
  h2: true,
  h3: true,
  h4: true,
  h5: true,
  h6: true,
};

const selectedType = (editor: Editor) =>
  getNearestBlock(editor).caseOf({
    just: (n) => (Element.isElement(n) && (parentTextTypes as any)[n.type] ? n.type : 'p'),
    nothing: () => 'p',
  });

const icon = (editor: Editor) => {
  const type = selectedType(editor);
  switch (type) {
    case 'h1':
      return 'title';
    case 'h2':
      return 'text_fields';
    default:
      return 'title';
  }
};

export const headingTypeDescs = [
  createButtonCommandDesc({
    icon: '',
    description: 'H1',
    active: (editor) => isActive(editor, ['h1']),
    execute: (_ctx, editor) => switchType(editor, 'h1'),
  }),
  createButtonCommandDesc({
    icon: '',
    description: 'H2',
    active: (editor) => isActive(editor, ['h2']),
    execute: (_ctx, editor) => switchType(editor, 'h2'),
  }),
];

export const headingLevelDesc = (editor: Editor) =>
  createButtonCommandDesc({
    icon: '',
    description: isActive(editor, 'h1') ? 'H1' : 'H2',
    active: (editor) => isActive(editor, ['h1', 'h2']),
    execute: () => {},
  });

export const commandDesc: CommandDescription = {
  type: 'CommandDesc',
  icon,
  description: () => 'Title (# or ##)',
  command: {
    execute: (_context, editor) => {
      const nextType = ((selected) => {
        switch (selected) {
          case 'h2':
          case 'h3':
          case 'h4':
          case 'h5':
          case 'h6':
            return 'p';
          case 'h1':
            return 'h2';
          default:
            return 'h1';
        }
      })(selectedType(editor));

      Transforms.setNodes(
        editor,
        { type: nextType },
        { match: (n) => Element.isElement(n) && (parentTextTypes as any)[n.type] },
      );
    },
    precondition: (editor) => isTopLevel(editor) && isActive(editor, Object.keys(parentTextTypes)),
  },
  active: (editor) => isActive(editor, ['h1', 'h2']),
};
