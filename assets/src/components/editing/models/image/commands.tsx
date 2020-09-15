import { CommandDesc } from 'components/editing/commands/interfaces';
import * as ContentModel from 'data/content/model';
import { Modal } from 'components/editing/toolbars/Modal';
import { useState } from 'react';
import { modalActions } from 'actions/modal';

interface Props {
  onDone: (params: any) => void;
  onCancel: () => void;
  model: ContentModel.Image;
}
const ImageModal = ({ onDone, onCancel, model }: Props) => {
  const [value, setValue] = useState(model.alt);
  return (
    <Modal
      onCancel={(e) => {
        onCancel();
      }}
      onDone={() => onDone(value)}>
      <div>
        <h3 className="mb-2">Alternative Text</h3>
        <p className="mb-4">Write a short description of this image
        for visitors who are unable to see it.
        </p>
        <div className="m-auto" style={{
          width: 300,
          height: 200,
          backgroundImage: `url(${model.src})`,
          backgroundPosition: '50% 50%',
          backgroundSize: 'contain',
          backgroundRepeat: 'no-repeat',
        }}>
        </div>
        <input
          className="settings-input"
          value={value}
          onChange={e => setValue(e.target.value)}
          placeholder={'E.g., "Stack of blueberry pancakes with powdered sugar"'}
        />
      </div>
    </Modal>
  );
};

export const initCommands = (
  model: ContentModel.Image,
  onEdit: (updated: Partial<ContentModel.Image>) => void): CommandDesc[][] => {

  const setAlt = (alt: string) => {
    onEdit({ alt });
  };
  const setDisplay = (display: ContentModel.MediaDisplayMode) => {
    onEdit({ display });
  };

  return [
    [
      {
        type: 'CommandDesc',
        icon: () => 'align_horizontal_left',
        description: () => 'Float left',
        active: e => model.display === 'float_left',
        command: {
          execute: (c, e, p) => setDisplay('float_left'),
          precondition: () => true,
        },
      },
      {
        type: 'CommandDesc',
        icon: () => 'align_horizontal_center',
        description: () => 'Center image',
        active: e => model.display === 'block',
        command: {
          execute: (c, e, p) => setDisplay('block'),
          precondition: () => true,
        },
      },
      {
        type: 'CommandDesc',
        icon: () => 'align_horizontal_right',
        description: () => 'Float right',
        active: e => model.display === 'float_right',
        command: {
          execute: (c, e, p) => setDisplay('float_right'),
          precondition: () => true,
        },
      },
    ],
    [
      {
        type: 'CommandDesc',
        icon: () => '',
        description: () => 'Alt text',
        command: {
          execute: (context, editor, params) => {
            const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
            const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

            display(
              <ImageModal
                model={model}
                onDone={(...args) => {
                  dismiss();
                  setAlt(...args);
                }}
                onCancel={() => {
                  dismiss();
                }}
              />,
            );
          },
          precondition: () => true,
        },
      },
    ],
  ];
};
