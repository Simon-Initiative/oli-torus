import { FullScreenModal } from 'components/editing/toolbar/FullScreenModal';
import React, { useState } from 'react';
import * as ContentModel from 'data/content/model/elements/types';

interface ModalProps {
  onDone: (x: any) => void;
  onCancel: () => void;
  model: ContentModel.ImageBlock | ContentModel.ImageInline;
}
export const ImageModal = ({ onDone, onCancel, model }: ModalProps) => {
  const [alt, setAlt] = useState(model.alt);
  const [width, setWidth] = useState(model.width);

  return (
    <FullScreenModal onCancel={(_e) => onCancel()} onDone={() => onDone({ alt, width })}>
      <div>
        <h3 className="mb-2">Settings</h3>
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
          You can manually set the image width here and the height will scale automatically.
        </p>
        <div className="mb-4">
          <span>
            Width:{' '}
            <input
              type="number"
              value={width}
              onChange={(e) => {
                const width = parseInt(e.target.value);
                !Number.isNaN(width) && setWidth(width);
              }}
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
    </FullScreenModal>
  );
};
