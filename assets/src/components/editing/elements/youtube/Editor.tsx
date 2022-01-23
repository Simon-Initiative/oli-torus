import React from 'react';
import { ReactEditor, useSelected, useFocused, useEditor, useSlate } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import * as Settings from 'components/editing/elements/settings/Settings';
import { displayModelToClassName } from 'data/content/utils';
import { CaptionEditor } from 'components/editing/elements/settings/CaptionEditor';

export const CUTE_OTTERS = 'zHIIzcWqsP0';

export type YouTubeProps = EditorProps<ContentModel.YouTube>;

export const YouTubeEditor = (props: YouTubeProps) => {
  const focused = useFocused();
  const selected = useSelected();
  const editor = useSlate();

  const parameters = 'disablekb=1&modestbranding=1&showinfo=0&rel=0&controls=0';
  const fullSrc =
    'https://www.youtube.com/embed/' + (props.model.src || CUTE_OTTERS) + '?' + parameters;

  const onEdit = (updated: Partial<ContentModel.YouTube>) =>
    updateModel<ContentModel.YouTube>(editor, props.model, updated);

  const borderStyle =
    focused && selected
      ? { border: 'solid 3px lightblue', borderRadius: 0 }
      : { border: 'solid 3px transparent' };

  return (
    <div {...props.attributes} className="youtube-editor" contentEditable={false}>
      {props.children}
      <div className="embed-responsive embed-responsive-16by9 img-thumbnail" style={borderStyle}>
        <iframe className="embed-responsive-item" src={fullSrc} allowFullScreen></iframe>
      </div>
      <CaptionEditor onEdit={(caption) => onEdit({ caption })} model={props.model} />
    </div>
  );
};
