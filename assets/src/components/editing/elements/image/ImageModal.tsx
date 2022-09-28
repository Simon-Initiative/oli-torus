import React, { useState } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { Modal, ModalSize } from 'components/modal/Modal';

interface ModalProps {
  onDone: (x: any) => void;
  onCancel: () => void;
  model: ContentModel.ImageBlock | ContentModel.ImageInline;
}
export const ImageModal = ({ onDone, onCancel, model }: ModalProps) => {
  const [alt, setAlt] = useState(model.alt);
  const [width, setWidth] = useState(model.width);

  const clearWidth = () => setWidth(undefined);

  return (
    <Modal
      title="Image Settings"
      size={ModalSize.LARGE}
      okLabel="Save"
      cancelLabel="Cancel"
      onCancel={() => onCancel()}
      onOk={() => onDone({ alt, width })}
    >
      <div>
        <div
          className="mx-auto mb-4"
          style={{
            width: 300,
            height: 200,
            backgroundImage: `url(${model.src})`,
            backgroundPosition: '50% 50%',
            backgroundSize: 'contain',
            backgroundRepeat: 'no-repeat',
          }}
        />
        <h4 className="mb-2">Size</h4>
        <p className="mb-2">
          Manually set the image width and the height will scale automatically.
        </p>
        <div className="mb-4">
          <span>
            Width:{' '}
            <input
              type="number"
              value={width || ''}
              onChange={(e) => {
                const width = parseInt(e.target.value);
                !Number.isNaN(width) && setWidth(width);
              }}
            />
          </span>
          {width && (
            <button className="btn btn-sm btn-secondary ml-2" onClick={clearWidth}>
              Clear
            </button>
          )}
        </div>
        <h4 className="mb-2">Alternative Text</h4>
        <p className="mb-4">
          Specify alternative text to be rendered when the image cannot be rendered.
        </p>

        <input
          className="form-control"
          value={alt}
          onChange={(e) => setAlt(e.target.value)}
          placeholder="Enter a short description of this image"
        />
      </div>
    </Modal>
  );
};
