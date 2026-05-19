import React, { useCallback } from 'react';
import { Button } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { MIMETYPE_FILTERS } from '../../../../../components/media/manager/MediaManager';
import { selectProjectSlug } from '../../../store/app/slice';
import { MediaPickerModal } from '../../Modal/MediaPickerModal';
import { MediaBrowserComponent, TorusMediaBrowserWrapper } from './TorusMediaBrowserWrapper';

const _TorusTranscriptBrowser: MediaBrowserComponent = ({
  id,
  label,
  value,
  onChange,
  onBlur,
  onFocus,
}) => {
  const [pickerOpen, , openPicker, closePicker] = useToggle();
  const projectSlug: string = useSelector(selectProjectSlug);

  const commitSelection = useCallback(() => {
    onBlur(id, value);
    closePicker();
  }, [closePicker, id, onBlur, value]);

  const hasTranscript = !!value;

  return (
    <span>
      <label className="form-label">{label}</label>
      {hasTranscript ? (
        <div className="truncate-left">{value}</div>
      ) : (
        <div className="truncate-left">No Transcript File</div>
      )}

      <Button
        onClick={() => {
          if (onFocus) onFocus();
          openPicker();
        }}
        type="button"
        variant="secondary"
        size="sm"
        aria-label="Select Transcript File"
      >
        <i className="fa-solid fa-file-lines"></i>
      </Button>

      <a
        href="#"
        style={{ marginLeft: '5px', textDecoration: 'underline' }}
        onClick={(e) => {
          e.preventDefault();
          if (onFocus) onFocus();
          openPicker();
        }}
      >
        Upload or Link Transcript
      </a>

      {pickerOpen && (
        <MediaPickerModal
          onUrlChanged={onChange}
          initialSelection={value}
          projectSlug={projectSlug}
          onOK={commitSelection}
          onCancel={closePicker}
          mimeFilter={MIMETYPE_FILTERS.ALL}
          title="Select Transcript File"
        />
      )}
    </span>
  );
};

export const TorusTranscriptBrowser = TorusMediaBrowserWrapper(_TorusTranscriptBrowser);
