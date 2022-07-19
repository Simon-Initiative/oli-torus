import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import React from 'react';
import { useSlate } from 'slate-react';

interface Props {
  description: CommandDescription;
}
export const ButtonContent = (props: Props) => {
  const editor = useSlate();
  const { icon, description } = props.description;

  return (
    <div className="editorToolbar__buttonIndicator">
      {icon(editor) ? (
        <span className="material-icons">{icon(editor)}</span>
      ) : (
        <span className="toolbar-button-text">{description(editor)}</span>
      )}
    </div>
  );
};
