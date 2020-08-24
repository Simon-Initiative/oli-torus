import { ReactEditor } from 'slate-react';
import { Editor, Range, Text } from 'slate';
import { getHighestTopLevel } from 'components/editor/utils';

export function shouldShowInsertionToolbar(editor: ReactEditor) {
  const { selection } = editor;

  if (!selection) return false;

  // True if the cursor is in a paragraph at the toplevel with no content
  const isCursorAtEmptyLine = () => {
    const nodes = Array.from(Editor.nodes(editor, { at: selection }));
    if (nodes.length !== 3) {
      return false;
    }
    const [[first], [second], [third]] = nodes;
    return Editor.isEditor(first) &&
      second.type === 'p' &&
      Text.isText(third) && third.text === '';
  };

  return ReactEditor.isFocused(editor) &&
    Range.isCollapsed(selection);
    // isCursorAtEmptyLine();
}

export function positionInsertion(el: HTMLElement, editor: ReactEditor) {
  const menu = el;

  getHighestTopLevel(editor).lift((n) => {
    const node = ReactEditor.toDOMNode(editor, n);
    menu.style.position = 'absolute';
    menu.style.opacity = '1';
    menu.style.top = node.offsetTop + 'px';
    menu.style.left = node.offsetLeft - 20 + 'px';
  });

  // const native = window.getSelection() as any;
  // const range = native.getRangeAt(0);
  // const rect = range.getBoundingClientRect();

  // // menu.style.position = 'absolute';
  // // menu.style.top = rect.top + window.pageYOffset - 30 + 'px';
  // // menu.style.left = rect.left + window.pageXOffset + 'px';
  // // menu.style.top = window.pageYOffset + 'px';
  // // menu.style.left = window.pageXOffset + 'px';

  // menu.style.position = 'absolute';
  // menu.style.top = (rect.top + window.pageYOffset) - 30 + 'px';

  // const left = (rect.left +
  //   window.pageXOffset -
  //   menu.offsetWidth / 2) - 50;

  // menu.style.left = `${left}px`;
}
