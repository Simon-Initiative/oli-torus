import React, { useState } from 'react';
import { ReactEditor, useSelected, useFocused } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from 'components/editor/editors/utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editor/editors/interfaces';
import * as Settings from 'components/editor/editors/settings/Settings';
import { YouTubeSettings } from 'components/editor/editors/youtube/YoutubeSettings';

export const CUTE_OTTERS = 'zHIIzcWqsP0';

export interface YouTubeProps extends EditorProps<ContentModel.YouTube> {}

export const YouTubeEditor = (props: YouTubeProps) => {

  const [isPopoverOpen, setIsPopoverOpen] = useState(false);
  const { attributes, children, editor } = props;
  const [model, setModel] = useState(props.model);

  const editMode = getEditMode(editor);

  const focused = useFocused();
  const selected = useSelected();

  // Note that it is important that any interactive portions of a void editor
  // must be enclosed inside of a "contentEditable=false" container. Otherwise,
  // slate does some weird things that non-deterministically interface with click
  // events.

  const { src } = model;
  const parameters = 'disablekb=1&modestbranding=1&showinfo=0&rel=0&controls=0';
  const fullSrc = 'https://www.youtube.com/embed/' +
    (src === '' ? CUTE_OTTERS : src) + '?' + parameters;

  const onEdit = (updated: ContentModel.YouTube) => {
    updateModel<ContentModel.YouTube>(editor, model, updated);

    setIsPopoverOpen(false);
  };

  const onRemove = () => {
    ($('#remove-button') as any).tooltip('hide');

    const path = ReactEditor.findPath(editor, model);
    Transforms.removeNodes(editor, { at: path });

    setIsPopoverOpen(false);
  };

  const contentFn = () => <YouTubeSettings
    model={model}
    editMode={editMode}
    commandContext={props.commandContext}
    onRemove={onRemove}
    onEdit={onEdit}/>;

  const setCaption = (caption: string) => setModel(Object.assign({}, model, { caption }));


  const borderStyle = focused && selected
    ? { border: 'solid 3px lightblue', borderRadius: 0 } : { border: 'solid 3px transparent' };


  return (
    <div {...attributes} className="ml-4 mr-4">

      <div contentEditable={false} style={{ userSelect: 'none' }}
        className="youtube-editor">

        <div
          onClick={e => Transforms.select(editor, ReactEditor.findPath(editor, model))}
          className="embed-responsive embed-responsive-16by9 img-thumbnail" style={borderStyle}>
          <iframe className="embed-responsive-item"
            src={fullSrc} allowFullScreen></iframe>
        </div>
        <Settings.ToolPopupButton
          contentFn={contentFn}
          setIsPopoverOpen={setIsPopoverOpen}
          isPopoverOpen={isPopoverOpen}
          label="YouTube" />
        <Settings.Input
          value={model.caption}
          onChange={value => setCaption(value)}
          editor={editor}
          model={model}
          placeholder="Type caption for YouTube video"
        />

      </div>

      {children}
    </div>
  );
};
