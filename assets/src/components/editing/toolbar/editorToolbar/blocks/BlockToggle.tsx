import React from 'react';
import { useSlate } from 'slate-react';
import { toggleBlockquote } from 'components/editing/elements/blockquote/blockquoteActions';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { toggleHeading } from 'components/editing/elements/heading/headingActions';
import { toggleList } from 'components/editing/elements/list/listActions';
import { toggleParagraph } from 'components/editing/elements/paragraph/paragraphActions';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { activeBlockType } from 'components/editing/toolbar/toolbarUtils';

export const toggleTextTypes = [toggleParagraph, toggleHeading, toggleList, toggleBlockquote];

interface BlockToggleProps {
  blockInsertOptions: CommandDescription[];
}
export const BlockToggle = ({ blockInsertOptions }: BlockToggleProps) => {
  const editor = useSlate();
  const activeBlockDesc = activeBlockType(editor);

  if (blockInsertOptions.length === 0) return null;
  return (
    <Toolbar.Group>
      <DropdownButton description={activeBlockDesc} showDropdownArrow={true}>
        {toggleTextTypes
          .filter((type) => !type.active?.(editor))
          .map((desc, i) => (
            <DescriptiveButton key={i} description={desc} />
          ))}
      </DropdownButton>
    </Toolbar.Group>
  );
};
