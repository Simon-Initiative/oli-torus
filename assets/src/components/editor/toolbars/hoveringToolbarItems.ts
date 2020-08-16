import { createToggleFormatCommand as format } from 'components/editor/commands/commands';
import { commandDesc as titleCmd } from 'components/editor/commands/buttons/Title';
import { commandDesc as codeCmd } from 'components/editor/commands/buttons/Code';
import { olCommandDesc as olCmd, ulCommandDesc as ulCmd } from 'components/editor/commands/buttons/Lists';
import { commandDesc as quoteCmd } from 'components/editor/commands/buttons/Blockquote';
import { commandDesc as linkCmd } from 'components/editor/commands/buttons/Link';

export const hoverMenuCommands = [
  [
    format('format_bold', 'strong', 'Bold'),
    format('format_italic', 'em', 'Italic'),
    linkCmd,
  ],
  [
    olCmd,
    ulCmd,
  ],
  [
    titleCmd,
    quoteCmd,
    codeCmd,
  ],
];
