import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { editor } from 'monaco-editor';
import React from 'react';
import { DropdownButton } from 'react-bootstrap';

export const addItemDropdown = createButtonCommandDesc({
  icon: 'add',
  description: 'Add item',
  execute: () => {},
  active: (_e) => false,
});

const insertMenu = props.toolbarInsertDescs.length > 0 && (
  <Toolbar.Group>
    <DropdownButton description={addItemDropdown}>
      {props.toolbarInsertDescs
        .filter((desc) => desc.command.precondition(editor))
        .map((desc, i) => (
          <DescriptiveButton key={i} description={desc} />
        ))}
    </DropdownButton>
  </Toolbar.Group>
);
