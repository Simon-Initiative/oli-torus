import { createToggleFormatCommand as format } from 'components/editor/commands/commands';
import { commandDesc as titleCmd } from 'components/editor/commands/TitleCmd';
import { commandDesc as codeCmd } from 'components/editor/commands/CodeCmd';
import { olCommandDesc as olCmd, ulCommandDesc as ulCmd }
  from 'components/editor/commands/ListsCmd';
import { commandDesc as quoteCmd } from 'components/editor/commands/QuoteCmd';
import { commandDesc as linkCmd } from 'components/editor/commands/LinkCmd';

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
