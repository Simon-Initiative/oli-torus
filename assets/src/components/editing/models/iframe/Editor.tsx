import React, { useState } from 'react';
import { ReactEditor, useSelected, useFocused } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from 'components/editing/models/utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editing/models/interfaces';
import * as Settings from 'components/editing/models/settings/Settings';
import { displayModelToClassName } from 'data/content/utils';

// tslint:disable-next-line: class-name
export interface iFrameProps extends EditorProps<ContentModel.iFrame> { }

export const iFrameEditor = (props: iFrameProps) => {

  const { attributes, children, editor, model } = props;

  const editMode = getEditMode(editor);

  const focused = useFocused();
  const selected = useSelected();

  const { src } = model;

  const onEdit = (updated: ContentModel.iFrame) => {
    updateModel<ContentModel.iFrame>(editor, model, updated);
  };

  const update = (attrs: Partial<ContentModel.iFrame>) =>
    Object.assign({}, model, attrs);

  const setCaption = (caption: string) => {
    onEdit(update({ caption }));
  };

  const borderStyle = focused && selected
    ? { border: 'solid 3px lightblue', borderRadius: 0 } : { border: 'solid 3px transparent' };

  // Note that it is important that any interactive portions of a void editor
  // must be enclosed inside of a "contentEditable=false" container. Otherwise,
  // slate does some weird things that non-deterministically interface with click
  // events.
  return (
    <div
      {...attributes}
      contentEditable={false}
      style={{ userSelect: 'none' }}
      className={'iFrame-editor ' + displayModelToClassName(model.display)}>
      <div
        onClick={e => Transforms.select(editor, ReactEditor.findPath(editor, model))}
        className="embed-responsive embed-responsive-16by9 img-thumbnail" style={borderStyle}>
        <iframe className="embed-responsive-item" src={src} allowFullScreen></iframe>
      </div>
      <div contentEditable={false}>
        <Settings.Input
          editMode={editMode}
          value={model.caption}
          onChange={setCaption}
          editor={editor}
          model={model}
          placeholder="Enter an optional caption for iFrame video"
        />
      </div>

      {children}
    </div>
  );
};
