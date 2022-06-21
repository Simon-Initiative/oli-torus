import { toggleHeading } from 'components/editing/elements/heading/headingActions';
import { toggleList } from 'components/editing/elements/list/listActions';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import React from 'react';
import { useSlate } from 'slate-react';
import { toggleBlockquote } from 'components/editing/elements/blockquote/blockquoteActions';
import { toggleParagraph } from 'components/editing/elements/paragraph/paragraphActions';
import { activeBlockType } from 'components/editing/toolbar/toolbarUtils';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';

export const toggleTextTypes = [toggleParagraph, toggleHeading, toggleList, toggleBlockquote];

interface BlockToggleProps {
  blockInsertOptions: CommandDescription[];
}
export const BlockToggle = ({ blockInsertOptions }: BlockToggleProps) => {
  const editor = useSlate();
  const activeBlockDesc = activeBlockType(editor);

  if (blockInsertOptions.length === 0) return null;
  return (
    <Toolbar.VerticalGroup>
      <DropdownButton description={activeBlockDesc}>
        {toggleTextTypes
          .filter((type) => !type.active?.(editor))
          .map((desc, i) => (
            <DescriptiveButton key={i} description={desc} />
          ))}
      </DropdownButton>
    </Toolbar.VerticalGroup>
  );
};
