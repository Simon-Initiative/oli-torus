import { FullScreenModal } from 'components/editing/toolbar/FullScreenModal';
import React, { useState } from 'react';
import * as ContentModel from 'data/content/model/elements/types';

interface ModalProps {
  onDone: (x: any) => void;
  onCancel: () => void;
  model: ContentModel.Image;
}
export const ImageModal = ({ onDone, onCancel, model }: ModalProps) => {
  const [value, setValue] = useState(model.alt);
  return (
    <FullScreenModal onCancel={(_e) => onCancel()} onDone={() => onDone(value)}>
      <div>
        <h3 className="mb-2">Alternative Text</h3>
        <p className="mb-4">
          Write a short description of this image for visitors who are unable to see it.
        </p>
        <div
          className="m-auto"
          style={{
            width: 300,
            height: 200,
            backgroundImage: `url(${model.src})`,
            backgroundPosition: '50% 50%',
            backgroundSize: 'contain',
            backgroundRepeat: 'no-repeat',
          }}
        ></div>
        <input
          className="form-control"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          placeholder={'E.g., "Stack of blueberry pancakes with powdered sugar"'}
        />
      </div>
    </FullScreenModal>
  );
};
