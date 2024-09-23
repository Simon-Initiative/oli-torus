import React, { ReactEventHandler } from 'react';
import { Modal } from 'react-bootstrap';

export const QuillImageUploader = (props: any) => {
  const [imageURL, setImageURL] = React.useState<string>('');
  const [imageAltText, setImageAltText] = React.useState<string>('');
  const handleOnImageURLChange: ReactEventHandler<HTMLInputElement> = (event) => {
    const el = event.target as HTMLInputElement;
    const val = el.value;
    setImageURL(val);
  };
  const handleOnImageAlTextChange: ReactEventHandler<HTMLInputElement> = (event) => {
    const el = event.target as HTMLInputElement;
    const val = el.value;
    setImageAltText(val);
  };
  return (
    <React.Fragment>
      {
        <>
          <Modal show={props.showImageSelectorDailog}>
            <Modal.Header closeButton={true} className="px-8 pb-0">
              <h3 className="modal-title font-bold">MCQ - Insert Image</h3>
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
            </Modal.Body>
            <Modal.Footer className="px-8 pb-6 flex-row justify-items-stretch">
              <button
                id="btnDelete"
                className="btn btn-primary flex-grow basis-1"
                onClick={() => {
                  props.handleImageDetailsSave(imageURL, imageAltText);
                }}
              >
                {`Save`}
              </button>
              <button id="btnCancel" className="btn btn-default flex-grow basis-1">
                Cancel
              </button>
            </Modal.Footer>
          </Modal>
        </>
      }
    </React.Fragment>
  );
};
