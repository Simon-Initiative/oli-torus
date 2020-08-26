import { createToggleFormatCommand as format } from 'components/editor/commands/commands';
import { commandDesc as titleCmd } from 'components/editor/commands/TitleCmd';
import { olCommandDesc as olCmd, ulCommandDesc as ulCmd }
  from 'components/editor/commands/ListsCmd';
import { commandDesc as quoteCmd } from 'components/editor/commands/BlockquoteCmd';
import { commandDesc as linkCmd } from 'components/editor/commands/link/LinkCmd';
import { isActive } from 'components/editor/utils';

export const formatMenuCommands = [
  [
    format({ icon: 'format_bold', mark: 'strong', description: 'Bold' }),
    format({ icon: 'format_italic', mark: 'em', description: 'Italic' }),
    linkCmd,
    format({
      icon: 'code', mark: 'code', description: 'Code', precondition: editor => !isActive(editor, ['code']),
    }),
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
