import React, { useCallback, useRef, useState } from 'react';
import { AudioSource } from '../../../../data/content/model/elements/types';
import { MediaItem } from '../../../../types/media';
import { useAudio } from '../../../hooks/useAudio';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from '../../../media/manager/MediaManager';
import { UrlOrUpload } from '../../../media/UrlOrUpload';
import { CommandContext } from '../commands/interfaces';
import { AudioClipProvider } from './settings/AudioClipPickerSettings';

interface Props {
  clipSrc?: string;
  commandContext: CommandContext;
  onChange: (src?: AudioSource) => void;
  children?: React.ReactNode;
}

// Sub-component used in other editors to select & preview an audio clip.
// This version is suitable to use inside a modal dialog, it will open an absolute positioned
// div within the existing dialog, whereas <AudioClipPicker> opens it's own modal.
export const InlineAudioClipPicker: React.FC<Props> = ({
  clipSrc,
  onChange,
  commandContext,
  children,
}) => {
  const { audioPlayer, playAudio, isPlaying } = useAudio(clipSrc);
  const [pickerOpen, setPickerOpen] = useState(false);

  const onUrlSelection = (url: string) => {
    if (url.length > 0) {
      onChange({ url, contenttype: 'audio/mpeg' });
    } else {
      onChange(undefined);
    }
  };

  const closePicker = useCallback(() => setPickerOpen(false), []);
  const onMediaSelection = (sel: MediaItem[]) => {
    if (sel.length > 0) {
      const url = sel[0].url;
      const contenttype = sel[0].mimeType;
      onChange({ url, contenttype });
    } else {
      onChange(undefined);
    }
    setPickerOpen(false);
  };

  const onChangeAudio = useCallback(() => {
    setPickerOpen((current) => !current);
  }, []);

  const onRemoveAudio = useCallback(() => {
    if (isPlaying) {
      playAudio();
    }
    onChange(undefined);
  }, [isPlaying, onChange, playAudio]);

  return (
    <AudioClipProvider>
      <div className="audio-picker audio-picker-inline">
        {children}
        <button
          onClick={onChangeAudio}
          type="button"
          className="btn btn-sm btn-outline-secondary btn-pronunciation-audio tool-button"
          data-toggle="tooltip"
          data-placement="top"
          title="Browse for audio"
        >
          <i className="fa-regular fa-file-audio"></i>
        </button>
        {clipSrc && (
          <>
            {audioPlayer}
            <button
              type="button"
              onClick={playAudio}
              className="btn btn-sm btn-outline-success btn-pronunciation-audio tool-button"
              data-toggle="tooltip"
              data-placement="top"
              title="Preview audio file"
            >
              {isPlaying ? (
                <i className="fa-solid fa-circle-stop"></i>
              ) : (
                <i className="fa-solid fa-circle-play"></i>
              )}
            </button>
            <button
              type="button"
              onClick={onRemoveAudio}
              className="btn btn-sm btn-outline-danger btn-pronunciation-audio tool-button"
              data-toggle="tooltip"
              data-placement="top"
              title="Remove audio file"
            >
              <i className="fa-solid fa-trash"></i>
            </button>
          </>
        )}
      </div>
      {pickerOpen && (
        <div className="audio-clip-browser-modal">
          <UrlOrUpload
            onUrlChange={onUrlSelection}
            onMediaSelectionChange={onMediaSelection}
            projectSlug={commandContext.projectSlug}
            mimeFilter={MIMETYPE_FILTERS.AUDIO}
            selectionType={SELECTION_TYPES.SINGLE}
          />
          <div className="audio-clip-footer">
            <button className="btn btn-link" type="button" onClick={closePicker}>
              Cancel
            </button>
            <button className="btn btn-primary" type="button" onClick={closePicker}>
              Select Audio
            </button>
          </div>
        </div>
      )}
    </AudioClipProvider>
  );
};
