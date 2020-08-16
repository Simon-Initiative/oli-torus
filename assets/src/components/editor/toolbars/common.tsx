import React from 'react';
import { useSlate } from 'slate-react';

export function hideToolbar(el: HTMLElement) {
  el.style.display = 'none';
}

export function isToolbarHidden(el: HTMLElement) {
  return el.style.display === 'none';
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
