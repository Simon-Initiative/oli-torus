import { Tooltip } from 'components/common/Tooltip';
import React, { useCallback, useRef } from 'react';
import { AudioSource } from '../../../../data/content/model/elements/types';
import { useAudio } from '../../../hooks/useAudio';
import { CommandContext } from '../commands/interfaces';
import { selectAudio } from './settings/AudioClipPickerSettings';

interface Props {
  clipSrc?: string;
  commandContext: CommandContext;
  onChange: (src?: AudioSource) => void;
  children?: React.ReactNode;
}

// Sub-component used in other editors to select & preview an audio clip.
// This will open a modal to choose an audio clip, bootstrap does not support
// multiple modals open at once, so if you're already in a modal please use
// InlineAudioClipPicker instead.
export const AudioClipPicker: React.FC<Props> = ({
  clipSrc,
  onChange,
  commandContext,
  children,
}) => {
  const { audioPlayer, playAudio, isPlaying } = useAudio(clipSrc);

  const onChangeAudio = useCallback(() => {
    selectAudio(commandContext.projectSlug, clipSrc).then((src: AudioSource) => {
      onChange(src);
    });
  }, [commandContext.projectSlug, clipSrc, onChange]);

  const onRemoveAudio = useCallback(() => {
    if (isPlaying) {
      playAudio();
    }
    onChange(undefined);
  }, [isPlaying, onChange, playAudio]);

  return (
    <div className="audio-picker">
      {children}
      <Tooltip title="Browse for audio">
        <button
          onClick={onChangeAudio}
          type="button"
          className="btn btn-sm btn-outline-secondary btn-pronunciation-audio tool-button"
        >
          <i className="fa-regular fa-file-audio"></i>
        </button>
      </Tooltip>
      {clipSrc && (
        <>
          {audioPlayer}
          <Tooltip title="Preview audio file">
            <button
              type="button"
              onClick={playAudio}
              className="btn btn-sm btn-outline-success btn-pronunciation-audio tool-button"
            >
              {isPlaying ? (
                <i className="fa-solid fa-circle-stop"></i>
              ) : (
                <i className="fa-solid fa-circle-play"></i>
              )}
            </button>
          </Tooltip>
          <Tooltip title="Remove audio file">
            <button
              type="button"
              onClick={onRemoveAudio}
              className="btn btn-sm btn-outline-danger btn-pronunciation-audio tool-button"
            >
              <i className="fa-solid fa-trash"></i>
            </button>
          </Tooltip>
        </>
      )}
    </div>
  );
};
