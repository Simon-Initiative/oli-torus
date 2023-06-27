import React, { useCallback, useState } from 'react';
import { Modal, ModalSize } from 'components/modal/Modal';
import * as ContentModel from 'data/content/model/elements/types';

interface ModalProps {
  onDone: (x: any) => void;
  onCancel: () => void;
  model: ContentModel.YouTube;
}
export const YouTubeModal = ({ onDone, onCancel, model }: ModalProps) => {
  const [src, setSrc] = useState(model.src);
  const [alt, setAlt] = useState(model.alt);
  const [startTime, setStart] = useState(model.startTime ? String(model.startTime) : '');
  const [endTime, setEnd] = useState(model.endTime ? String(model.endTime) : '');

  const onOk = useCallback(() => {
    const start = startTime ? parseInt(startTime) : undefined;
    const end = endTime ? parseInt(endTime) : undefined;
    onDone({ alt, width: model.width, src, startTime: start, endTime: end });
  }, [alt, endTime, model.width, onDone, src, startTime]);

  return (
    <Modal
      title="YouTube Video Settings"
      size={ModalSize.MEDIUM}
      okLabel="Save"
      cancelLabel="Cancel"
      onCancel={() => onCancel()}
      onOk={onOk}
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

        <h4 className="my-2">Start / End play time</h4>

        <div className="flex flex-row">
          <div className="text-center">
            <div className="flex flex-row">
              <input
                type="number"
                className="form-control w-8"
                value={startTime}
                onChange={(e) => setStart(e.target.value)}
              />
            </div>
            <label>Start Time (sec)</label>
          </div>

          <div className="mx-2">-</div>

          <div className="text-center">
            <div className="flex flex-row">
              <input
                type="number"
                className="form-control w-8"
                value={endTime}
                onChange={(e) => setEnd(e.target.value)}
              />
            </div>
            <label>End Time (sec)</label>
          </div>
        </div>
      </div>
    </Modal>
  );
};
