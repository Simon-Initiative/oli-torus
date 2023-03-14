import React from 'react';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { switchType } from 'components/editing/elements/commands/toggleTextTypes';
import { getNearestBlock, isActive, isTopLevel } from 'components/editing/slateUtils';
import { Editor, Element, Transforms } from 'slate';

export const toggleHeading = createButtonCommandDesc({
  icon: <i className="fa-solid fa-heading"></i>,
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

export const headingTypeDescs = [
  createButtonCommandDesc({
    description: 'H1',
    active: (editor) => isActive(editor, ['h1']),
    execute: (_ctx, editor) => switchType(editor, 'h1'),
  }),
  createButtonCommandDesc({
    description: 'H2',
    active: (editor) => isActive(editor, ['h2']),
    execute: (_ctx, editor) => switchType(editor, 'h2'),
  }),
];

export const headingLevelDesc = (editor: Editor) =>
  createButtonCommandDesc({
    description: isActive(editor, 'h1') ? 'H1' : 'H2',
    active: (editor) => isActive(editor, ['h1', 'h2']),
    execute: () => {},
  });

export const commandDesc: CommandDescription = {
  type: 'CommandDesc',
  icon: () => <i className="fa-solid fa-heading"></i>,
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
