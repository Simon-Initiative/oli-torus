import React, { useCallback } from 'react';
import { Button, ButtonGroup } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { useAudio } from '../../../../../components/hooks/useAudio';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { MIMETYPE_FILTERS } from '../../../../../components/media/manager/MediaManager';
import { selectProjectSlug } from '../../../store/app/slice';
import { MediaPickerModal } from '../../Modal/MediaPickerModal';
import { MediaBrowserComponent, TorusMediaBrowserWrapper } from './TorusMediaBrowserWrapper';

const _TorusAudioBrowser: MediaBrowserComponent = ({ id, label, value, onChange, onBlur }) => {
  const [pickerOpen, , openPicker, closePicker] = useToggle();
  const projectSlug: string = useSelector(selectProjectSlug);
  const { audioPlayer, playAudio, isPlaying } = useAudio(value);

  const commitSelection = useCallback(() => {
    onBlur(id, value);
    closePicker();
  }, [closePicker, id, onBlur, value]);

  const hasAudio = !!value;

  return (
    <span>
      <label className="form-label">{label}</label>
      {hasAudio && (
        <>
          <div className="truncate-left">{value}</div>
          {audioPlayer}
        </>
      )}

      {hasAudio || <div className="truncate-left">No Audio</div>}

      <ButtonGroup>
        <Button
          onClick={openPicker}
          type="button"
          variant="secondary"
          size="sm"
          aria-label="Select Audio File"
        >
          <i className="fa-solid fa-microphone"></i>
        </Button>

        {hasAudio && (
          <Button size="sm" variant="secondary" onClick={playAudio}>
            {isPlaying ? (
              <i className="fa-solid fa-circle-stop"></i>
            ) : (
              <i className="fa-solid fa-circle-play"></i>
            )}
          </Button>
        )}
      </ButtonGroup>

      {pickerOpen && (
        <MediaPickerModal
          onUrlChanged={onChange}
          initialSelection={value}
          projectSlug={projectSlug}
          onOK={commitSelection}
          onCancel={closePicker}
          mimeFilter={MIMETYPE_FILTERS.AUDIO}
          title="Select Audio File"
        />
      )}
    </span>
  );
};

export const TorusAudioBrowser = TorusMediaBrowserWrapper(_TorusAudioBrowser);
