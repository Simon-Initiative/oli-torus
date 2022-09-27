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
      <button
        onClick={onChangeAudio}
        type="button"
        className="btn btn-sm btn-outline-secondary btn-pronunciation-audio"
        data-toggle="tooltip"
        data-placement="top"
        title="Browse for audio"
      >
        <span className="material-icons ">audio_file</span>
      </button>
      {clipSrc && (
        <>
          {audioPlayer}
          <button
            type="button"
            onClick={playAudio}
            className="btn btn-sm btn-outline-success btn-pronunciation-audio "
            data-toggle="tooltip"
            data-placement="top"
            title="Preview audio file"
          >
            <span className="material-icons">{isPlaying ? 'stop_circle' : 'play_circle'}</span>
          </button>
          <button
            type="button"
            onClick={onRemoveAudio}
            className="btn btn-sm btn-outline-danger btn-pronunciation-audio "
            data-toggle="tooltip"
            data-placement="top"
            title="Remove audio file"
          >
            <span className="material-icons">delete</span>
          </button>
        </>
      )}
    </div>
  );
};
