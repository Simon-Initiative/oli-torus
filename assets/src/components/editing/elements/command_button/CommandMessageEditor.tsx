import React from 'react';
import { CommandTarget } from './commandButtonTypes';
import { DefaultCommandMessageEditor } from './DefaultCommandMessageEditor';

interface Props {
  value: string;
  target?: CommandTarget;
  onChange: (value: string) => void;
}
/**
 * Presents a list of editors for the command message, lets you pick one of them, and then use it.
 * (ex, the default text-based editor, and the video cue point editor)
 */
export const CommandMessageEditor: React.FC<Props> = ({ value, target, onChange }) => {
  const [selectedEditorIndex, setSelectedEditorIndex] = React.useState(0);
  const setSelectedEditorIndexHandler = (index: number) => () => setSelectedEditorIndex(index);
  const editors = target?.MessageEditor
    ? [target.MessageEditor, DefaultCommandMessageEditor]
    : [DefaultCommandMessageEditor];

  const ActiveEditor = editors[selectedEditorIndex] || DefaultCommandMessageEditor;

  return (
    <div className="container">
      <div className="row">
        <div className="col">
          <ul className="list-group">
            {editors.map((Editor, index) => (
              <li
                className={
                  selectedEditorIndex == index ? 'list-group-item active' : 'list-group-item '
                }
                onClick={setSelectedEditorIndexHandler(index)}
                key={index}
              >
                {Editor.label}
              </li>
            ))}
          </ul>
        </div>
        <div className="col-span-9">
          <ActiveEditor onChange={onChange} value={value} />
        </div>
      </div>
    </div>
  );
};
