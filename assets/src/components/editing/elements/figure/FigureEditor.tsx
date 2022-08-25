import React, { useCallback, useState } from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import * as ContentModel from '../../../../data/content/model/elements/types';
import { useEditModelCallback } from '../utils';
import { ReactEditor, useSlate } from 'slate-react';
import { Editor, Transforms } from 'slate';

interface Props extends EditorProps<ContentModel.Figure> {}

const TitleEditor: React.FC<{
  title: string;
  onBlur: () => void;
  onEdit: (val: string) => void;
}> = ({ title, onEdit, onBlur }) => {
  const [isEditing, setEditing] = useState(!title || title.length === 0);

  const cancelEditing = useCallback(() => {
    setEditing(false);
    onBlur && onBlur();
  }, [onBlur]);

  const onKeypress = useCallback(
    (e: React.KeyboardEvent<HTMLInputElement>) => {
      if (e.key === 'Enter') {
        cancelEditing();
      }
    },
    [cancelEditing],
  );

  const onInputCreated = useCallback((ref: HTMLInputElement) => {
    setTimeout(() => ref?.focus()); // If you try and set focus right away, slate will not render the editor correctly
  }, []);

  const toggleEdit = useCallback(() => {
    setEditing(true);
  }, []);

  return isEditing ? (
    <input
      ref={onInputCreated}
      placeholder="Figure Title"
      className="form-control "
      type="text"
      value={title}
      onBlur={cancelEditing}
      onKeyPress={onKeypress}
      onChange={(e) => onEdit(e.target.value)}
    />
  ) : (
    <span className="title" onClick={toggleEdit}>
      {title || <i className="title-placeholder">Figure Title</i>}
    </span>
  );
};

export const FigureEditor: React.FC<Props> = ({ model, attributes, children }) => {
  const onEdit = useEditModelCallback(model);
  const editor = useSlate();

  const onTitleBlur = useCallback(() => {
    // When we're done editing the title, it'd be nice to put the cursor into the figure content body
    setTimeout(() => {
      ReactEditor.focus(editor);
      const path = ReactEditor.findPath(editor, model);
      Transforms.select(editor, path);
    });
  }, [editor, model]);

  const onEditTitle = useCallback(
    (val: string) => {
      onEdit({
        title: val,
      });
    },
    [onEdit],
  );

  return (
    <div className="figure-editor figure" {...attributes}>
      <figure>
        <figcaption contentEditable={false}>
          <TitleEditor onBlur={onTitleBlur} title={model.title} onEdit={onEditTitle} />
        </figcaption>
        <div className="figure-content">{children}</div>
      </figure>
    </div>
  );
};
