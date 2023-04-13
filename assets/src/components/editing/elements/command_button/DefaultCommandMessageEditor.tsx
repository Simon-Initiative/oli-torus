import React, { useCallback } from 'react';
import { MessageEditorComponent } from './commandButtonTypes';

export const DefaultCommandMessageEditor: MessageEditorComponent = ({ onChange, value }) => {
  const onChangeHandler = useCallback(
    (event: React.ChangeEvent<HTMLInputElement>) => {
      onChange(event.target.value);
    },
    [onChange],
  );
  return (
    <div>
      <div className="form-group">
        <label htmlFor="command-editor">Command to send</label>
        <input
          value={value}
          type="text"
          className="form-control"
          name="command-editor"
          onChange={onChangeHandler}
        />
        <small className="form-text text-muted">
          Components will have a specific format of command they expect, please consult the
          documentation of the target component for this format.
        </small>
      </div>
    </div>
  );
};
DefaultCommandMessageEditor.label = 'Raw Command Editor';
