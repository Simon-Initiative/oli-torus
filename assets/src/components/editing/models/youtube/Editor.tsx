import React, { useState } from 'react';
import { ReactEditor, useSelected, useFocused } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from 'components/editing/models/utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editing/models/interfaces';
import * as Settings from 'components/editing/models/settings/Settings';
import { displayModelToClassName } from 'data/content/utils';

export const CUTE_OTTERS = 'zHIIzcWqsP0';

export interface YouTubeProps extends EditorProps<ContentModel.YouTube> { }

export const YouTubeEditor = (props: YouTubeProps) => {

  const { attributes, children, editor, model } = props;

  const editMode = getEditMode(editor);

  const focused = useFocused();
  const selected = useSelected();

  const { src } = model;
  const parameters = 'disablekb=1&modestbranding=1&showinfo=0&rel=0&controls=0';
  const fullSrc = 'https://www.youtube.com/embed/' +
    (src === '' ? CUTE_OTTERS : src) + '?' + parameters;

  const onEdit = (updated: ContentModel.YouTube) => {
    updateModel<ContentModel.YouTube>(editor, model, updated);
  };

  const update = (attrs: Partial<ContentModel.YouTube>) =>
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
      style={{ userSelect: 'none' }}
      className={'youtube-editor ' + displayModelToClassName(model.display)}>
      <div
        contentEditable={false}
        onClick={e => Transforms.select(editor, ReactEditor.findPath(editor, model))}
        className="embed-responsive embed-responsive-16by9 img-thumbnail" style={borderStyle}>
        <iframe className="embed-responsive-item"
          src={fullSrc} allowFullScreen></iframe>
      </div>
      <div contentEditable={false}>
        <Settings.Input
          editMode={editMode}
          value={model.caption}
          onChange={setCaption}
          editor={editor}
          model={model}
          placeholder="Set a caption for this YouTube video"
        />
      </div>

      {children}
    </div>
  );
};
