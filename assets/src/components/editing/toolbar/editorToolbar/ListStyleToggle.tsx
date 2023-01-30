import React from 'react';

import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { createButtonCommandDesc } from '../../elements/commands/commandFactories';

interface ListStyleProps {
  listStyleOptions: CommandDescription[];
}

/**
 * The drop-down menu that lets you pick a list style in the editor. There are different
 * styles for ordered and unordered lists, so pass in an appropriate listStyleOptions for
 * the current list type.
 */
export const ListStyleToggle = ({ listStyleOptions }: ListStyleProps) => {
  if (listStyleOptions.length === 0) return null;
  return (
    <DropdownButton
      description={createButtonCommandDesc({
        icon: <i className="fa-regular fa-rectangle-list"></i>,
        description: 'List Style',
        active: (_editor) => false,
        execute: (_ctx, _editor) => null,
      })}
    >
      {listStyleOptions.map((desc, i) => (
        <DescriptiveButton key={i} description={desc} />
      ))}
    </DropdownButton>
  );
};
