import React, { useState } from 'react';
import { updateModel, getEditMode } from 'components/editing/models/utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editing/models/interfaces';
import * as Settings from 'components/editing/models/settings/Settings';

// eslint-disable-next-line
interface Props extends EditorProps<ContentModel.Table> { }
export const TableEditor = (props: Props) => {

  const { attributes, children, editor, model } = props;

  const editMode = getEditMode(editor);

  const onEdit = (updated: ContentModel.Table) => {
    updateModel<ContentModel.Table>(editor, model, updated);
  };
  const update = (attrs: Partial<ContentModel.Table>) =>
    Object.assign({}, model, attrs);

  const setCaption = (caption: string) => {
    onEdit(update({ caption }));
  };

  // Note that it is important that any interactive portions of a void editor
  // must be enclosed inside of a "contentEditable=false" container. Otherwise,
  // slate does some weird things that non-deterministically interface with click
  // events.

  return (
    <div {...attributes} className="table-editor">
      <table>
        <tbody>
          {children}
        </tbody>
      </table>
      <div contentEditable={false} style={{ userSelect: 'none' }}>
        <Settings.Input
          editMode={editMode}
          value={model.caption}
          onChange={setCaption}
          editor={editor}
          model={model}
          placeholder="Set a caption for this table"
        />
      </div>
    </div>
  );
};
