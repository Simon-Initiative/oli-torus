import { createToggleFormatCommand as format } from 'components/editor/commands/commands';
import { commandDesc as titleCmd } from 'components/editor/commands/TitleCmd';
import { olCommandDesc as olCmd, ulCommandDesc as ulCmd }
  from 'components/editor/commands/ListsCmd';
import { commandDesc as quoteCmd } from 'components/editor/commands/BlockquoteCmd';
import { commandDesc as linkCmd } from 'components/editor/commands/LinkCmd';

export const formatMenuCommands = [
  [
    format('format_bold', 'strong', 'Bold'),
    format('format_italic', 'em', 'Italic'),
    linkCmd,
    format('code', 'code', 'Code'),
  ],
  [
    olCmd,
    ulCmd,
  ],
  [
    titleCmd,
    quoteCmd,
  ],
];
