import React, { useState } from 'react';
import { Tooltip } from 'components/common/Tooltip';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { Modal, ModalSize } from 'components/modal/Modal';
import * as ContentModel from 'data/content/model/elements/types';
import { modalActions } from '../../../../actions/modal';
import { useAudio } from '../../../hooks/useAudio';
import { useToggle } from '../../../hooks/useToggle';
import { MIMETYPE_FILTERS } from '../../../media/manager/MediaManager';
import { Toolbar } from '../../toolbar/Toolbar';
import { DescriptiveButton } from '../../toolbar/buttons/DescriptiveButton';
import { createButtonCommandDesc } from '../commands/commandFactories';
import { MediaInfo, MediaPickerPanel } from '../common/MediaPickerPanel';

interface SettingsButtonProps {
  model: ContentModel.Audio;
  projectSlug: string;
  commandContext: CommandContext;
  onEdit: (attrs: Partial<ContentModel.Audio>) => void;
}
export const SettingsButton = (props: SettingsButtonProps) => {
  return (
    <DescriptiveButton
      description={createButtonCommandDesc({
        icon: <i className="fa-solid fa-circle-play"></i>,
        description: 'Settings',
        execute: (_context, _editor, _params) =>
          window.oliDispatch(
            modalActions.display(
              <AudioSettingsModal
                commandContext={props.commandContext}
                model={props.model}
                onEdit={(audio: Partial<ContentModel.Audio>) => {
                  window.oliDispatch(modalActions.dismiss());
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
                <Tooltip title="Preview audio file">
                  <button
                    type="button"
                    onClick={playAudio}
                    className="btn btn-outline-primary btn-pronunciation-audio tool-button"
                  >
                    <span>
                      {isPlaying ? (
                        <i className="fa-solid fa-circle-stop"></i>
                      ) : (
                        <i className="fa-solid fa-circle-play"></i>
                      )}
                    </span>
                  </button>
                </Tooltip>
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
