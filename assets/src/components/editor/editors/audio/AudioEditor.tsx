import React, { useState } from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from '../utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editor/editors/interfaces';
import * as Settings from 'components/editor/editors/settings/Settings';
import { AudioSettings } from './AudioSettings';

export interface AudioProps extends EditorProps<ContentModel.Audio> {
}

export const AudioEditor = (props: AudioProps) => {

  const [isPopoverOpen, setIsPopoverOpen] = useState(false);
  const { attributes, children, editor } = props;
  const { model } = props;

  const editMode = getEditMode(editor);

  const onEdit = (updated: ContentModel.Audio) => {
    updateModel<ContentModel.Audio>(editor, model, updated);
    setIsPopoverOpen(false);
  };

  const onRemove = () => {
    ($('#remove-button') as any).tooltip('hide');

    const path = ReactEditor.findPath(editor, model);
    Transforms.removeNodes(editor, { at: path });

    setIsPopoverOpen(false);
  };

  // Note that it is important that any interactive portions of a void editor
  // must be enclosed inside of a "contentEditable=false" container. Otherwise,
  // slate does some weird things that non-deterministically interface with click
  // events.

  const { src } = model;

  const contentFn = () => <AudioSettings
    commandContext={props.commandContext}
    model={model}
    editMode={editMode}
    onRemove={onRemove}
    onEdit={onEdit}/>;

  return (
    <div {...attributes} className="ml-4 mr-4">

      <div contentEditable={false} style={{ userSelect: 'none' }}>

        <div className="ml-4">
          <audio src={src} controls />
        </div>
        <Settings.ToolPopupButton
          contentFn={contentFn}
          setIsPopoverOpen={setIsPopoverOpen}
          isPopoverOpen={isPopoverOpen}
          label="Audio" />
        <Settings.Caption caption={model.caption}/>

      </div>

      {children}
    </div>
  );
};
