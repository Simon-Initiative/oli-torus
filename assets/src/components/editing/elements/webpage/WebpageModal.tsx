import React, { useState } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import Modal, { ModalSize } from 'components/modal/Modal';

interface ModalProps {
  onDone: (x: any) => void;
  onCancel: () => void;
  model: ContentModel.Webpage;
}
export const WebpageModal = ({ onDone, onCancel, model }: ModalProps) => {
  const [src, setSrc] = useState(model.src);
  const [alt, setAlt] = useState(model.alt ?? '');
  const [width, setWidth] = useState(model.width);

  return (
    <Modal
      title=""
      size={ModalSize.MEDIUM}
      okLabel="Save"
      cancelLabel="Cancel"
      onCancel={onCancel}
      onInsert={() => onDone({ alt, width, src })}
    >
      <div>
        <h3 className="mb-2">Settings</h3>
        <h4 className="mb-2">Change Webpage Embed URL</h4>
        <div className="mb-4">
          <span>
            Webpage Embed URL:
            <input
              className="form-control"
              value={src}
              onChange={(e) => setSrc(e.target.value)}
              placeholder="Webpage Embed URL"
            />
          </span>
        </div>

        <h4 className="mb-2">Alternative Text</h4>
        <p className="mb-4">
          Write a short description of this image for visitors who are unable to see it.
        </p>

        <input
          className="form-control"
          value={alt}
          onChange={(e) => setAlt(e.target.value)}
          placeholder={'E.g., "Stack of blueberry pancakes with powdered sugar"'}
        />
      </div>
    </Modal>
  );
};
