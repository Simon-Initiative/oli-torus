import { AudioSource } from '../../../../data/content/model/elements/types';
import { MediaItem } from '../../../../types/media';
import { useAudio } from '../../../hooks/useAudio';
import { UrlOrUpload } from '../../../media/UrlOrUpload';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from '../../../media/manager/MediaManager';
import { CommandContext } from '../commands/interfaces';
import { AudioClipProvider } from './settings/AudioClipPickerSettings';
import { Tooltip } from 'components/common/Tooltip';
import React, { useCallback, useRef, useState } from 'react';

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
