import { modalActions } from 'actions/modal';
import { selectImage } from 'components/editing/commands/ImageCmd';
import { CommandDesc } from 'components/editing/commands/interfaces';
import { FullScreenModal } from 'components/editing/toolbars/FullScreenModal';
import * as ContentModel from 'data/content/model/elements/types';
import * as React from 'react';
import { useState } from 'react';
import { Maybe } from 'tsmonad';

interface Props {
  onDone: (params: any) => void;
  onCancel: () => void;
  model: ContentModel.Image;
}
const ImageModal = ({ onDone, onCancel, model }: Props) => {
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

export const initCommands = (
  model: ContentModel.Image,
  onEdit: (updated: Partial<ContentModel.Image>) => void,
): CommandDesc[][] => {
  const setSrc = (src: string) => {
    onEdit({ src });
  };
  const setAlt = (alt: string) => {
    onEdit({ alt });
  };

  return [
    [
      {
        type: 'CommandDesc',
        icon: () => 'insert_photo',
        description: () => 'Select Image',
        command: {
          execute: (context, _editor) => {
            selectImage(context.projectSlug, model.src).then((selection) =>
              Maybe.maybe(selection).caseOf({
                just: (src) => setSrc(src),
                // eslint-disable-next-line
                nothing: () => {},
              }),
            );
          },
          precondition: (_editor) => {
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
          execute: (_context, _editor, _params) => {
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
