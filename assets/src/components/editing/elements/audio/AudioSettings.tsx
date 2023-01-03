import React, { useState, useEffect, useRef } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import * as Settings from 'components/editing/elements/common/settings/Settings';
import { selectAudio } from 'components/editing/elements/audio/audioActions';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { useDispatch } from 'react-redux';
import { DescriptiveButton } from '../../toolbar/buttons/DescriptiveButton';
import { createButtonCommandDesc } from '../commands/commandFactories';
import { modalActions } from '../../../../actions/modal';
import { Toolbar } from '../../toolbar/Toolbar';
import { Modal, ModalSize } from 'components/modal/Modal';
import { MediaInfo, MediaPickerPanel } from '../common/MediaPickerPanel';
import { MIMETYPE_FILTERS } from '../../../media/manager/MediaManager';
import { useToggle } from '../../../hooks/useToggle';
import { useAudio } from '../../../hooks/useAudio';

interface SettingsButtonProps {
  model: ContentModel.Audio;
  projectSlug: string;
  commandContext: CommandContext;
  onEdit: (attrs: Partial<ContentModel.Audio>) => void;
}
export const SettingsButton = (props: SettingsButtonProps) => {
  const dispatch = useDispatch();
  return (
    <DescriptiveButton
      description={createButtonCommandDesc({
        icon: 'play_circle_filled',
        description: 'Settings',
        execute: (_context, _editor, _params) =>
          dispatch(
            modalActions.display(
              <AudioSettingsModal
                commandContext={props.commandContext}
                model={props.model}
                onEdit={(audio: Partial<ContentModel.Audio>) => {
                  dispatch(modalActions.dismiss());
                  props.onEdit(audio);
                }}
                onCancel={() => window.oliDispatch(modalActions.dismiss())}
              />,
            ),
          ),
      })}
    />
  );
};

interface SettingsProps {
  model: ContentModel.Audio;
  projectSlug: string;
  commandContext: CommandContext;
  onEdit: (attrs: Partial<ContentModel.Audio>) => void;
}
export const AudioToolbar = (props: SettingsProps) => {
  return (
    <div className="video-settings">
      <Toolbar context={props.commandContext}>
        <Toolbar.Group>
          <SettingsButton
            commandContext={props.commandContext}
            projectSlug={props.commandContext.projectSlug}
            model={props.model}
            onEdit={props.onEdit}
          />
        </Toolbar.Group>
      </Toolbar>
    </div>
  );
};

type AudioSettingsProps = {
  model: ContentModel.Audio;
  onEdit: (model: ContentModel.Audio) => void;
  commandContext: CommandContext;
  onCancel: () => void;
};

const AudioSettingsModal = (props: AudioSettingsProps) => {
  // Which selection is active, URL or in course page
  const [model, setModel] = useState(props.model);
  const [audioPickerOpen, , openAudioPicker, closeAudioPicker] = useToggle();

  const { audioPlayer, playAudio, isPlaying } = useAudio(model.src);
  const setAlt = (alt: string) => setModel((model) => ({ ...model, alt }));
  const setSrc = (src: string) => setModel((model) => ({ ...model, src }));
  const onOk = () => {
    props.onEdit(model);
  };
  const onAudioSelected = (video: MediaInfo[]) => {
    if (!video || video.length != 1) return;
    closeAudioPicker();
    setSrc(video[0].url);
  };

  const fileName = model.src ? model.src.substr(model.src.lastIndexOf('/') + 1) : '';

  return (
    <Modal
      title="Audio Settings"
      size={ModalSize.X_LARGE}
      okLabel="Save"
      cancelLabel="Cancel"
      onCancel={props.onCancel}
      onOk={onOk}
    >
      <div>
        {audioPlayer}
        <form className="form">
          <label>File</label>
          <div className="input-group mb-3 mr-sm-2">
            <input type="text" readOnly value={fileName} className="form-control" />
            <div className="input-group-append">
              <button onClick={openAudioPicker} className="btn btn-outline-primary" type="button">
                Select
              </button>
              {model.src && (
                <button
                  type="button"
                  onClick={playAudio}
                  className="btn btn-sm btn-outline-success btn-pronunciation-audio tool-button"
                  data-toggle="tooltip"
                  data-placement="top"
                  title="Preview audio file"
                >
                  <span className="material-icons">
                    {isPlaying ? 'stop_circle' : 'play_circle'}
                  </span>
                </button>
              )}
            </div>
          </div>

          <label>Alt Text</label>
          <input
            type="text"
            value={model.alt || ''}
            onChange={(e) => setAlt(e.target.value)}
            className="form-control mr-sm-2"
          />
        </form>
      </div>
      <MediaPickerPanel
        projectSlug={props.commandContext.projectSlug}
        onMediaChange={onAudioSelected}
        open={audioPickerOpen}
        mimeFilter={MIMETYPE_FILTERS.AUDIO}
        onCancel={() => closeAudioPicker()}
      />
    </Modal>
  );
};
