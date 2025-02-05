import React, { useCallback } from 'react';
import { Button } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { selectProjectSlug } from '../../../store/app/slice';
import { MediaPickerModal } from '../../Modal/MediaPickerModal';
import { MediaBrowserComponent, TorusMediaBrowserWrapper } from './TorusMediaBrowserWrapper';

const _TorusImageBrowser: MediaBrowserComponent = ({
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

  const hasImage = value && value !== '/images/placeholder-image.svg';

  return (
    <span>
      <label className="form-label">{label}</label>
      {hasImage && (
        <>
          <div className="truncate-left">{value}</div>

          <div className="image-preview">
            <img className="img-fluid" src={value} />
          </div>
        </>
      )}

      {hasImage || <div className="truncate-left">No Image</div>}

      <Button
        onClick={() => {
          if (onFocus) onFocus();
          openPicker();
        }}
        type="button"
        variant="secondary"
        size="sm"
        aria-label="Select Image"
      >
        <i className="fa-solid fa-image"></i>
      </Button>

      <a
        href="#"
        style={{ marginLeft: '5px', textDecoration: 'underline' }}
        onClick={() => {
          if (onFocus) onFocus();
          openPicker();
        }}
      >
        Upload or Link Image
      </a>
      {pickerOpen && (
        <MediaPickerModal
          onUrlChanged={onChange}
          initialSelection={value}
          projectSlug={projectSlug}
          onOK={commitSelection}
          onCancel={closePicker}
        />
      )}
    </span>
  );
};

export const TorusImageBrowser = TorusMediaBrowserWrapper(_TorusImageBrowser);
