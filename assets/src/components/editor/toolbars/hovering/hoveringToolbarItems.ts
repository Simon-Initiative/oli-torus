import { createToggleFormatCommand as format } from 'components/editor/commands/commands';
import { commandDesc as titleCmd } from 'components/editor/commands/CmdTitle';
import { commandDesc as codeCmd } from 'components/editor/commands/CmdCode';
import { olCommandDesc as olCmd, ulCommandDesc as ulCmd }
  from 'components/editor/commands/CmdLists';
import { commandDesc as quoteCmd } from 'components/editor/commands/CmdQuote';
import { commandDesc as linkCmd } from 'components/editor/commands/CmdLink';

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
