import React, { ReactEventHandler } from 'react';
import { Modal } from 'react-bootstrap';

interface QuillImageUploaderProps {
  handleImageDetailsSave: (imageSrc: string, imageAltText: string) => void;
  handleImageDailogClose: () => void;
  showImageSelectorDailog?: boolean;
  initialImageSrc?: string;
  initialImageAltText?: string;
  isEditingImage?: boolean;
}
export const QuillImageUploader: React.FC<QuillImageUploaderProps> = ({
  handleImageDetailsSave,
  showImageSelectorDailog,
  handleImageDailogClose,
  initialImageSrc = '',
  initialImageAltText = '',
  isEditingImage = false,
}) => {
  const [imageURL, setImageURL] = React.useState<string>('');
  const [imageAltText, setImageAltText] = React.useState<string>('');
  const [errorMessage, setErrorMessage] = React.useState<string>('');

  React.useEffect(() => {
    if (!showImageSelectorDailog) {
      setImageURL('');
      setImageAltText('');
      setErrorMessage('');
      return;
    }

    setImageURL(initialImageSrc);
    setImageAltText(initialImageAltText);
    setErrorMessage('');
  }, [showImageSelectorDailog, initialImageSrc, initialImageAltText]);

  const handleOnImageURLChange: ReactEventHandler<HTMLInputElement> = (event) => {
    const el = event.target as HTMLInputElement;
    const val = el.value;
    setImageURL(val);
    setErrorMessage('');
  };
  const handleOnImageAlTextChange: ReactEventHandler<HTMLInputElement> = (event) => {
    const el = event.target as HTMLInputElement;
    const val = el.value;
    setImageAltText(val);
    setErrorMessage('');
  };

  const onSave = () => {
    if (!imageURL.trim()) {
      setErrorMessage('Image URL is required.');
      return;
    }
    handleImageDetailsSave(imageURL.trim(), imageAltText.trim());
  };

  return (
    <React.Fragment>
      {
        <>
          <Modal show={showImageSelectorDailog} onHide={handleImageDailogClose}>
            <Modal.Header closeButton={true} className="px-8 pb-0">
              <h3 className="modal-title font-bold">
                {isEditingImage ? 'Edit Image' : 'Insert Image'}
              </h3>
            </Modal.Header>
            <Modal.Body className="px-8">
              <div style={{ width: '100%' }}>
                <label htmlFor={`url-text-input`}>Image URL</label>
                <input
                  id="url-text-input"
                  type="text"
                  placeholder="Enter the image url"
                  value={imageURL}
                  onChange={handleOnImageURLChange}
                  style={{ width: '100%' }}
                />
              </div>
              <div className={`short-text-input`} style={{ width: '100%' }}>
                <label htmlFor={`alt-text-input`}>Alt Text</label>
                <input
                  name="janus-input-text"
                  id={`alt-text-input`}
                  type="text"
                  placeholder="Enter image alt text"
                  onChange={handleOnImageAlTextChange}
                  value={imageAltText}
                  style={{ width: '100%' }}
                />
              </div>
              {errorMessage && <div className="text-danger mt-2">{errorMessage}</div>}
            </Modal.Body>
            <Modal.Footer className="px-8 pb-6 flex-row justify-items-stretch">
              <button id="btnDelete" className="btn btn-primary flex-grow basis-1" onClick={onSave}>
                {`Save`}
              </button>
              <button
                id="btnCancel"
                onClick={handleImageDailogClose}
                className="btn btn-default flex-grow basis-1"
              >
                Cancel
              </button>
            </Modal.Footer>
          </Modal>
        </>
      }
    </React.Fragment>
  );
};
