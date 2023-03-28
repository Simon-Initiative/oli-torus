import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import React from 'react';
import { useSlate } from 'slate-react';
import { CommandButton } from '../../buttons/CommandButton';

export const insertItemDropdown = createButtonCommandDesc({
  icon: <i className="fa-solid fa-plus"></i>,
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

  const filtered = blockInsertOptions.filter((desc) => desc.command.precondition(editor));
  const [priorityInsertOptions, remainingInsertOptions] = [filtered.slice(0, 2), filtered.slice(2)];

  return (
    <Toolbar.Group>
      {priorityInsertOptions.map((desc, i) => (
        <CommandButton key={i} description={desc} />
      ))}
      {remainingInsertOptions.length > 0 && (
        <DropdownButton description={insertItemDropdown} showDropdownArrow={false}>
          {remainingInsertOptions.map((desc, i) => (
            <DescriptiveButton key={i} description={desc} />
          ))}
        </DropdownButton>
      )}
    </Toolbar.Group>
  );
};
