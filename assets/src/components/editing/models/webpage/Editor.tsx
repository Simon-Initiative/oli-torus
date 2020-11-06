import React from 'react';
import { ReactEditor, useSelected, useFocused } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from 'components/editing/models/utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editing/models/interfaces';
import * as Settings from 'components/editing/models/settings/Settings';
import { displayModelToClassName } from 'data/content/utils';

export interface WebpageProps extends EditorProps<ContentModel.Webpage> { }

export const WebpageEditor = (props: WebpageProps) => {

  const { attributes, children, editor, model } = props;

  const editMode = getEditMode(editor);

  const focused = useFocused();
  const selected = useSelected();

  const { src } = model;

  const onEdit = (updated: ContentModel.Webpage) => {
    updateModel<ContentModel.Webpage>(editor, model, updated);
  };

  const update = (attrs: Partial<ContentModel.Webpage>) =>
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
      className={'Webpage-editor ' + displayModelToClassName(model.display)}>
      <div
        onClick={(e) => {
          ReactEditor.focus(editor);
          Transforms.select(editor, ReactEditor.findPath(editor, model));
        }}
        className="embed-responsive embed-responsive-16by9 img-thumbnail position-relative" style={borderStyle}>
        <iframe className="embed-responsive-item" src={src} allowFullScreen></iframe>
        <div className="position-absolute"style={{top: 0, bottom: 0, left: 0, right: 0}}></div>
      </div>
      <div contentEditable={false}>
        <Settings.Input
          editMode={editMode}
          value={model.caption}
          onChange={setCaption}
          editor={editor}
          model={model}
          placeholder="Set a caption for this webpage"
        />
      </div>

      {children}
    </div>
  );
};
