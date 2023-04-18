import React from 'react';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { insertImageInline } from 'components/editing/elements/image/imageActions';
import { commandDesc as linkCmd } from 'components/editing/elements/link/LinkCmd';
import {
  additionalFormattingOptions,
  boldDesc,
  inlineCodeDesc,
  italicDesc,
} from 'components/editing/elements/marks/toggleMarkActions';
import { popupCmdDesc as insertPopup } from 'components/editing/elements/popup/PopupCmd';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { insertInlineCallout } from '../../elements/callout/calloutActions';
import { insertCommandButton } from '../../elements/command_button/commandButtonActions';
import { insertForeign } from '../../elements/foreign/foreignActions';
import { insertInlineFormula } from '../../elements/formula/formulaActions';

interface Props {}
export const Inlines = (_props: Props) => {
  const basicFormattingOptions = [boldDesc, italicDesc, inlineCodeDesc, linkCmd].map((desc, i) => (
    <CommandButton key={i} description={desc} />
  ));

  const inlineInsertions = [
    insertForeign,
    insertPopup,
    insertImageInline,
    insertInlineFormula,
    insertInlineCallout,
    insertCommandButton,
  ];
  const moreInlineOptions = additionalFormattingOptions.concat(inlineInsertions);

  const seeMoreInlineOptions = createButtonCommandDesc({
    icon: <i className="fa-solid fa-ellipsis"></i>,
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
