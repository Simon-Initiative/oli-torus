import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import {
  additionalFormattingOptions,
  boldDesc,
  italicDesc,
  underLineDesc,
  inlineCodeDesc,
} from 'components/editing/elements/marks/toggleMarkActions';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import React from 'react';
import { commandDesc as linkCmd } from 'components/editing/elements/link/LinkCmd';
import { popupCmdDesc as insertPopup } from 'components/editing/elements/popup/PopupCmd';
import { insertImageInline } from 'components/editing/elements/image/imageActions';
import { insertInlineFormula } from '../../elements/formula/formulaActions';
import { insertInlineCallout } from '../../elements/callout/calloutActions';

interface Props {}
export const Inlines = (_props: Props) => {
  const basicFormattingOptions = [boldDesc, italicDesc, inlineCodeDesc, linkCmd].map((desc, i) => (
    <CommandButton key={i} description={desc} />
  ));

  const inlineInsertions = [
    insertPopup,
    insertImageInline,
    insertInlineFormula,
    insertInlineCallout,
  ];
  const moreInlineOptions = additionalFormattingOptions.concat(inlineInsertions);

  const seeMoreInlineOptions = createButtonCommandDesc({
    icon: 'more_horiz',
    description: 'More',
    execute: () => {},
    active: (e) => moreInlineOptions.some(({ active }) => active?.(e)),
  });

  return (
    <Toolbar.Group>
      {basicFormattingOptions}
      <DropdownButton description={seeMoreInlineOptions} showDropdownArrow={false}>
        {moreInlineOptions.map((desc, i) => (
          <DescriptiveButton key={i} description={desc} />
        ))}
      </DropdownButton>
    </Toolbar.Group>
  );
};
