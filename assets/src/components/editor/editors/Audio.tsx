import React, { useState, useEffect, useRef } from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from './utils';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps, CommandContext } from './interfaces';
import guid from 'utils/guid';
import * as Settings from './Settings';
import './Settings.scss';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection from 'components/modal/ModalSelection';
import { MediaManager } from 'components/media/manager/MediaManager.controller';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

export function selectAudio(projectSlug: string,
  model: ContentModel.Audio): Promise<ContentModel.Audio> {

  return new Promise((resolve, reject) => {

    const selected = { img: null };

    const mediaLibrary =
      <ModalSelection title="Select audio"
        onInsert={() => { dismiss(); resolve(selected.img as any); }}
        onCancel={() => dismiss()}
        disableInsert={true}
      >
        <MediaManager model={model}
          projectSlug={projectSlug}
          onEdit={() => { }}
          mimeFilter={MIMETYPE_FILTERS.AUDIO}
          selectionType={SELECTION_TYPES.SINGLE}
          initialSelectionPaths={[model.src]}
          onSelectionChange={(images: MediaItem[]) => {
            const first : ContentModel.Audio = { type: 'audio', src: images[0].url,
              children: [{ text: '' }], id: guid() };
            (selected as any).img = first;
          }} />
      </ModalSelection>;

    display(mediaLibrary);
  });
}

const command: Command = {
  execute: (context, editor: ReactEditor) => {
    const audio = ContentModel.create<ContentModel.Audio>(
      { type: 'audio', src: '', children: [{ text: '' }], id: guid() });
    selectAudio(context.projectSlug, audio)
    .then((img) => {
      Transforms.insertNodes(editor, img);
    });
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fas fa-music',
  description: 'Audio Clip',
  command,
};


type AudioSettingsProps = {
  model: ContentModel.Audio,
  onEdit: (model: ContentModel.Audio) => void,
  onRemove: () => void,
  commandContext: CommandContext,
  editMode: boolean,
};

const AudioSettings = (props: AudioSettingsProps) => {

  // Which selection is active, URL or in course page
  const [model, setModel] = useState(props.model);

  const ref = useRef();

  useEffect(() => {

    // Inits the tooltips, since this popover rendres in a react portal
    // this was necessary
    if (ref !== null && ref.current !== null) {
      ((window as any).$('[data-toggle="tooltip"]')).tooltip();
    }
  });

  const setSrc = (src: string) => setModel(Object.assign({}, model, { src }));
  const setCaption = (caption: string) => setModel(Object.assign({}, model, { caption }));
  const setAlt = (alt: string) => setModel(Object.assign({}, model, { alt }));

  const applyButton = (disabled: boolean) => <button onClick={(e) => {
    e.stopPropagation();
    e.preventDefault();
    props.onEdit(model);
  }}
  disabled={disabled}
  className="btn btn-primary ml-1">Apply</button>;

  const fileName = model.src.substr(model.src.lastIndexOf('/') + 1);

  return (
    <div className="settings-editor-wrapper">
      <div className="settings-editor" ref={ref as any}>

        <div className="d-flex justify-content-between mb-2">
          <div>
            Audio
          </div>

          <div>
            <Settings.Action icon="fas fa-trash" tooltip="Remove YouTube Video" id="remove-button"
              onClick={() => props.onRemove()}/>
          </div>
        </div>

        <form className="form">
        <label>File</label>
          <div className="input-group mb-3 mr-sm-2">
            <input type="text" readOnly value={fileName} className="form-control"/>
            <div className="input-group-append">
              <button
                onClick={() => selectAudio(
                  props.commandContext.projectSlug, model).then(img => setSrc(img.src))}
                className="btn btn-outline-primary" type="button">Select</button>
            </div>
          </div>

          <label>Caption</label>
          <input type="text" value={model.caption} onChange={e => setCaption(e.target.value)}
            className="form-control mr-sm-2"/>

          <label>Alt Text</label>
          <input type="text" value={model.alt} onChange={e => setAlt(e.target.value)}
            className="form-control mr-sm-2"/>
        </form>

        {applyButton(!props.editMode)}

      </div>
    </div>
  );
};

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
