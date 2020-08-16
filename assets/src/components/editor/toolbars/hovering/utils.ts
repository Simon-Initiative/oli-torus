import { ReactEditor } from 'slate-react';
import { Editor as SlateEditor, Range } from 'slate';

export function shouldHideToolbar(editor: ReactEditor) {
  const { selection } = editor;

  // Hide the toolbar where there is either:
  // 1. No selection
  // 2. The editor is not currently in focus
  // 3. The selection range is collapsed
  // 4. The selection current text is only whitespace or
  //    is the empty string

  // TODO: Prevent selections across block level elements

  return !selection ||
    !ReactEditor.isFocused(editor) ||
    Range.isCollapsed(selection) ||
    SlateEditor.string(editor, selection).trim() === '';
}

export function positionHovering(el: HTMLElement) {
  const menu = el;
  const native = window.getSelection() as any;
  const range = native.getRangeAt(0);
  const rect = (range as any).getBoundingClientRect();

  (menu as any).style.position = 'absolute';
  (menu as any).style.top =
    ((rect as any).top + (window as any).pageYOffset) - 30 + 'px';

  const left = ((rect as any).left +
    window.pageXOffset -
    (menu as any).offsetWidth / 2 +
    (rect as any).width / 2) - 50;

  (menu as any).style.left = `${left}px`;
}
