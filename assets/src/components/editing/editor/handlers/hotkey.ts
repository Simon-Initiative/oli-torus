import isHotkey from 'is-hotkey';
import { commandDesc as linkCmd } from 'components/editing/elements/link/LinkCmd';
import { Editor, Element, Node } from 'slate';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { toggleMark } from 'components/editing/elements/marks/toggleMarkActions';

const isBoldHotkey = isHotkey('mod+b');
const isItalicHotkey = isHotkey('mod+i');
const isCodeHotkey = isHotkey('mod+;');
const isLinkHotkey = isHotkey('mod+l');
const isDeleteKey = isHotkey(['Backspace', 'Delete']);

export const hotkeyHandler = (editor: Editor, e: KeyboardEvent, commandContext: CommandContext) => {
  if (isBoldHotkey(e)) {
    toggleMark(editor, 'strong');
  } else if (isItalicHotkey(e)) {
    toggleMark(editor, 'em');
  } else if (isCodeHotkey(e)) {
    toggleMark(editor, 'code');
  } else if (isLinkHotkey(e)) {
    linkCmd.command.execute(commandContext, editor);
  } else if (isDeleteKey(e)) {
    // Fix a slate bug with deleting selected inline void nodes
    const { selection } = editor;
    if (selection) {
      const currentNode = Node.parent(editor, selection.anchor.path);
      if (Element.isElement(currentNode)) {
        if (editor.isVoid(currentNode)) {
          e.preventDefault();
          editor.deleteBackward('block');
        }
      }
    }
  }
};
