import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import {
  toggleFormat,
  additionalFormattingOptions,
} from 'components/editing/elements/marks/toggleMarkActions';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { formatMenuCommands } from 'components/editing/toolbar/items';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import React from 'react';
import { DropdownButton } from 'react-bootstrap';

const formattingDropdownAction = createButtonCommandDesc({
  icon: 'expand_more',
  description: 'More',
  execute: (_context, _editor, _action) => {},
  active: (e) => additionalFormattingOptions.some((opt) => opt.active?.(e)),
});

export const formatMenuCommands = [
  toggleFormat({ icon: 'format_bold', mark: 'strong', description: 'Bold' }),
  toggleFormat({ icon: 'format_italic', mark: 'em', description: 'Italic' }),
  linkCmd,
];

const formatting = (
  <Toolbar.Group>
    {basicFormatting}
    {advancedFormatting}
  </Toolbar.Group>
);

const advancedFormatting = (
  <DropdownButton description={formattingDropdownAction}>
    {additionalFormattingOptions.map((desc, i) => (
      <DescriptiveButton key={i} description={desc} />
    ))}
  </DropdownButton>
);

const basicFormatting = formatMenuCommands.map((desc, i) => (
  <CommandButton key={i} description={desc} />
));
