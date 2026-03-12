import React, { useCallback } from 'react';
import { Button } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { MIMETYPE_FILTERS } from '../../../../../components/media/manager/MediaManager';
import { selectProjectSlug } from '../../../store/app/slice';
import { MediaPickerModal } from '../../Modal/MediaPickerModal';
import { MediaBrowserComponent, TorusMediaBrowserWrapper } from './TorusMediaBrowserWrapper';

const _TorusCaptionBrowser: MediaBrowserComponent = ({ id, label, value, onChange, onBlur }) => {
  const [pickerOpen, , openPicker, closePicker] = useToggle();
  const projectSlug: string = useSelector(selectProjectSlug);

  const commitSelection = useCallback(() => {
    onBlur(id, value);
    closePicker();
  }, [closePicker, id, onBlur, value]);

  const hasCaption = !!value;

  return (
    <span>
      <label className="form-label">{label}</label>

      {hasCaption && <div className="truncate-left">{value}</div>}
      {hasCaption || <div className="truncate-left">No Caption File</div>}

      <Button
        onClick={openPicker}
        type="button"
        variant="secondary"
        size="sm"
        aria-label="Select Caption File"
      >
        <i className="fa-solid fa-closed-captioning"></i>
      </Button>
      <a href="#" style={{ marginLeft: '5px', textDecoration: 'underline' }} onClick={openPicker}>
        Upload or Link Captions
      </a>
      {pickerOpen && (
        <MediaPickerModal
          onUrlChanged={onChange}
          initialSelection={value}
          projectSlug={projectSlug}
          onOK={commitSelection}
          onCancel={closePicker}
          mimeFilter={MIMETYPE_FILTERS.CAPTIONS}
          title="Select Caption File"
        />
      )}
    </span>
  );
};

export const TorusCaptionBrowser = TorusMediaBrowserWrapper(_TorusCaptionBrowser);
