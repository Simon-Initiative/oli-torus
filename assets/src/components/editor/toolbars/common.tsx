import React from 'react';
import { ReactEditor, useSlate } from 'slate-react';
import { Editor as SlateEditor, Range } from 'slate';

export function hideToolbar(el: HTMLElement) {
  el.style.display = 'none';
}

export function isToolbarHidden(el: HTMLElement) {
  return el.style.display === 'none';
}

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

export function showToolbar(el: HTMLElement) {
  el.style.display = 'block';
}

export const ToolbarButton =
({ icon, command, style, context, tooltip, active, description }: any) => {
  const editor = useSlate();

  return (
    <button
      data-toggle="tooltip"
      data-placement="top"
      title={tooltip}
      className={`btn btn-sm btn-light ${style} ${active && 'active'}`}
      onMouseDown={(event) => {
        event.preventDefault();
        command.execute(context, editor);
      }}
    >
      <span className="material-icons" data-icon={description}>{icon}</span>
    </button>
  );
};
