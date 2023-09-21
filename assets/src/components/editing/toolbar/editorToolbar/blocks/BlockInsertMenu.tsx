import React from 'react';
import { useSlate } from 'slate-react';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { CategorizedCommandList } from '../../CategorizedCommandList';
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
          <CategorizedCommandList commands={remainingInsertOptions} />
        </DropdownButton>
      )}
    </Toolbar.Group>
  );
};
