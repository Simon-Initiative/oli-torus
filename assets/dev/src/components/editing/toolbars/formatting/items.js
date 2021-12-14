import { commandDesc as quoteCmd } from 'components/editing/commands/BlockquoteCmd';
import { createToggleFormatCommand as format } from 'components/editing/commands/commands';
import { commandDesc as linkCmd } from 'components/editing/commands/LinkCmd';
import { olCommandDesc as olCmd, ulCommandDesc as ulCmd, } from 'components/editing/commands/ListsCmd';
import { commandDesc as popupCmd } from 'components/editing/commands/PopupCmd';
import { commandDesc as titleCmd } from 'components/editing/commands/TitleCmd';
import { isActive } from 'components/editing/utils';
export const formatMenuCommands = [
    [
        format({ icon: 'format_bold', mark: 'strong', description: 'Bold (⌘B)' }),
        format({ icon: 'format_italic', mark: 'em', description: 'Italic (⌘I)' }),
        linkCmd,
        format({
            icon: 'code',
            mark: 'code',
            description: 'Code (⌘;)',
            precondition: (editor) => !isActive(editor, ['code']),
        }),
        popupCmd,
    ],
    [olCmd, ulCmd],
    [titleCmd, quoteCmd],
];
//# sourceMappingURL=items.js.map