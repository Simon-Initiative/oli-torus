import React, { useCallback } from 'react';
import { Button } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { selectProjectSlug } from '../../../store/app/slice';
import { ImagePickerModal } from '../../Modal/ImagePickerModal';

interface Props {
  id: string;
  label: string;
  value: string;
  onChange: (url: string) => void;
  onBlur: (id: string, url: string) => void;
}

export const TorusImageBrowser: React.FC<Props> = ({ id, label, value, onChange, onBlur }) => {
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
        onClick={openPicker}
        type="button"
        variant="secondary"
        size="sm"
        aria-label="Select Image"
      >
        <span className="material-icons-outlined">image</span>
      </Button>

      {pickerOpen && (
        <ImagePickerModal
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
