import React, { useState } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { Modal, ModalSize } from 'components/modal/Modal';

interface ModalProps {
  onDone: (x: any) => void;
  onCancel: () => void;
  model: ContentModel.YouTube;
}
export const YouTubeModal = ({ onDone, onCancel, model }: ModalProps) => {
  const [src, setSrc] = useState(model.src);
  const [alt, setAlt] = useState(model.alt);

  return (
    <Modal
      title="YouTube Video Settings"
      size={ModalSize.MEDIUM}
      okLabel="Save"
      cancelLabel="Cancel"
      onCancel={() => onCancel()}
      onOk={() => onDone({ alt, width: model.width, src })}
    >
      <div>
        <h4 className="mb-2">Change Video</h4>
        <div className="mb-4">
          <span>
            YouTube Video ID or URL:
            <input
              className="form-control"
              value={src}
              onChange={(e) => setSrc(e.target.value)}
              placeholder="Video ID or URL"
            />
          </span>
        </div>

        <h4 className="mb-2">Alternative Text</h4>
        <p className="mb-4">
          Specify alternative text to be rendered when the video cannot be rendered.
        </p>

        <input
          className="form-control"
          value={alt}
          onChange={(e) => setAlt(e.target.value)}
          placeholder="Enter a short description of this video"
        />
      </div>
    </Modal>
  );
};
