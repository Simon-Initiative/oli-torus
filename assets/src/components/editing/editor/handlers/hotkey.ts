import isHotkey from 'is-hotkey';
import { ReactEditor } from 'slate-react';
import { toggleMark } from 'components/editing/commands/commands';
import { commandDesc as linkCmd } from 'components/editing/commands/LinkCmd';
import { CommandContext } from 'components/editing/models/interfaces';

const isBoldHotkey = isHotkey('mod+b');
const isItalicHotkey = isHotkey('mod+i');
const isCodeHotkey = isHotkey('mod+;');
const isLinkHotkey = isHotkey('mod+l');

export const hotkeyHandler = (
  editor: ReactEditor,
  e: KeyboardEvent,
  commandContext: CommandContext,
) => {
  if (isBoldHotkey(e)) {
    toggleMark(editor, 'strong');
  } else if (isItalicHotkey(e)) {
    toggleMark(editor, 'em');
  } else if (isCodeHotkey(e)) {
    toggleMark(editor, 'code');
  } else if (isLinkHotkey(e)) {
    linkCmd.command.execute(commandContext, editor);
  }
};
