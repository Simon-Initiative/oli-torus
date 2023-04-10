import React, { useCallback } from 'react';
import { Button } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { MIMETYPE_FILTERS } from '../../../../../components/media/manager/MediaManager';
import { selectProjectSlug } from '../../../store/app/slice';
import { MediaPickerModal } from '../../Modal/MediaPickerModal';
import { MediaBrowserComponent, TorusMediaBrowserWrapper } from './TorusMediaBrowserWrapper';

const _TorusVideoBrowser: MediaBrowserComponent = ({ id, label, value, onChange, onBlur }) => {
  const [pickerOpen, , openPicker, closePicker] = useToggle();
  const projectSlug: string = useSelector(selectProjectSlug);

  const commitSelection = useCallback(() => {
    onBlur(id, value);
    closePicker();
  }, [closePicker, id, onBlur, value]);

  const hasVideo = !!value;

  return (
    <span>
      <label className="form-label">{label}</label>

      {hasVideo && <div className="truncate-left">{value}</div>}
      {hasVideo || <div className="truncate-left">No Video</div>}

      <Button
        onClick={openPicker}
        type="button"
        variant="secondary"
        size="sm"
        aria-label="Select Video File"
      >
        <i className="fa-regular fa-file-video"></i>
      </Button>

      {pickerOpen && (
        <MediaPickerModal
          onUrlChanged={onChange}
          initialSelection={value}
          projectSlug={projectSlug}
          onOK={commitSelection}
          onCancel={closePicker}
          mimeFilter={MIMETYPE_FILTERS.VIDEO}
          title="Select Video File"
        />
      )}
    </span>
  );
};

export const TorusVideoBrowser = TorusMediaBrowserWrapper(_TorusVideoBrowser);
