import { CommandDesc } from 'components/editing/commands/interfaces';
import * as ContentModel from 'data/content/model';
import { Modal } from 'components/editing/toolbars/Modal';
import { useState } from 'react';
import { modalActions } from 'actions/modal';
import { commandDesc as imgCommandDesc, selectImage } from 'components/editing/commands/ImageCmd';
import { Maybe } from 'tsmonad';

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

  const setSrc = (src: string) => {
    onEdit({ src });
  };
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
        icon: () => 'insert_photo',
        description: () => 'Select Image',
        command: {
          execute: (context, editor) => {
            const at = editor.selection as any;
            selectImage(context.projectSlug, model.src)
            .then(selection => Maybe.maybe(selection).caseOf({
              just: src => setSrc(src),
              nothing: () => {},
            }));
          },
          precondition: (editor) => {
            return true;
          },
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
