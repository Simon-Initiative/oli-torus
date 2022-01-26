import React from 'react';
import { useSelected, useFocused } from 'slate-react';
import { onEditModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { CaptionEditor } from 'components/editing/elements/settings/CaptionEditor';

export const CUTE_OTTERS = 'zHIIzcWqsP0';

export type YouTubeProps = EditorProps<ContentModel.YouTube>;

export const YouTubeEditor = (props: YouTubeProps) => {
  const focused = useFocused();
  const selected = useSelected();

  const parameters = 'disablekb=1&modestbranding=1&showinfo=0&rel=0&controls=0';
  const fullSrc =
    'https://www.youtube.com/embed/' + (props.model.src || CUTE_OTTERS) + '?' + parameters;

  const onEdit = onEditModel(props.model);

  const borderStyle =
    focused && selected
      ? { border: 'solid 3px lightblue', borderRadius: 0 }
      : { border: 'solid 3px transparent' };

  return (
    <div {...props.attributes} className="youtube-editor" contentEditable={false}>
      {props.children}
      <div className="embed-responsive embed-responsive-16by9 img-thumbnail" style={borderStyle}>
        <iframe
          className="embed-responsive-item"
          src={fullSrc}
          allowFullScreen
          aria-label="Youtube video"
          frameBorder={0}
        ></iframe>
      </div>
      <CaptionEditor onEdit={(caption) => onEdit({ caption })} model={props.model} />
    </div>
  );
};
