import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import React from 'react';
import { useSlate } from 'slate-react';

export const insertItemDropdown = createButtonCommandDesc({
  icon: 'add',
  description: 'Add item',
  execute: () => {},
  active: (_e) => false,
});

interface Props {
  blockInsertOptions: CommandDescription[];
}
export const BlockInsertMenu = ({ blockInsertOptions }: Props) => {
  const editor = useSlate();
  if (blockInsertOptions.length === 0) return null;

  return (
    <Toolbar.Group>
      <DropdownButton description={insertItemDropdown}>
        {blockInsertOptions
          .filter((desc) => desc.command.precondition(editor))
          .map((desc, i) => (
            <DescriptiveButton key={i} description={desc} />
          ))}
      </DropdownButton>
    </Toolbar.Group>
  );
};
