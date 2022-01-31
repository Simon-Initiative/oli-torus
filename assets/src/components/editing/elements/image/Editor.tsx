import React, { useState } from 'react';
import { onEditModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Resizable } from 'components/misc/resizable/Resizable';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { Placeholder } from 'components/editing/elements/editors/Placeholder';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { CaptionEditor } from 'components/editing/elements/settings/CaptionEditor';
import { useElementSelected } from 'data/content/utils';
import { selectImage } from 'components/editing/elements/commands/ImageCmd';
import { Maybe } from 'tsmonad';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { modalActions } from 'actions/modal';
import { FullScreenModal } from 'components/editing/toolbar/FullScreenModal';

interface Props extends EditorProps<ContentModel.Image> {}
export const ImageEditor = (props: Props) => {
  const selected = useElementSelected();
  const onEdit = onEditModel(props.model);

  if (props.model.src === undefined)
    return (
      <Placeholder
        heading={
          <h3 className="d-flex align-items-center">
            <span className="material-icons mr-2">image</span>Image
          </h3>
        }
        attributes={props.attributes}
      >
        Upload an image from your media library or add one with a URL.
        <div>
          <button
            className="btn btn-primary mr-2"
            onClick={(_e) => {
              selectImage(props.commandContext.projectSlug, props.model.src).then((selection) =>
                Maybe.maybe(selection).caseOf({
                  just: (src) => onEdit({ src }),
                  nothing: () => {},
                }),
              );
            }}
          >
            Upload
          </button>
          <button
            className="btn btn-link"
            onClick={(_e) => {
              const src = prompt('Enter the image url:');
              if (!src) return;
              onEdit({ src });
            }}
          >
            Insert from URL
          </button>
          {props.children}
        </div>
      </Placeholder>
    );

  return (
    <div {...props.attributes} contentEditable={false}>
      {props.children}
      <HoverContainer
        style={{ margin: '0 auto', width: 'fit-content', display: 'block' }}
        isOpen={selected}
        align="start"
        position="top"
        content={
          <Toolbar context={props.commandContext}>
            <Toolbar.Group>
              <CommandButton
                description={{
                  type: 'CommandDesc',
                  icon: () => 'insert_photo',
                  description: () => 'Select Image',
                  command: {
                    execute: (context, _editor) => {
                      selectImage(context.projectSlug, props.model.src).then((selection) =>
                        Maybe.maybe(selection).caseOf({
                          just: (src) => onEdit({ src }),
                          nothing: () => {},
                        }),
                      );
                    },
                    precondition: (_editor) => {
                      return true;
                    },
                  },
                }}
              />
              <DescriptiveButton
                description={{
                  type: 'CommandDesc',
                  icon: () => '',
                  description: () => 'Alt text',
                  command: {
                    execute: (_context, _editor, _params) => {
                      const dismiss = () => window.oliDispatch(modalActions.dismiss());
                      const display = (c: any) => window.oliDispatch(modalActions.display(c));

                      display(
                        <ImageModal
                          model={props.model}
                          onDone={(alt) => {
                            dismiss();
                            onEdit({ alt });
                          }}
                          onCancel={() => {
                            dismiss();
                          }}
                        />,
                      );
                    },
                    precondition: () => true,
                  },
                }}
              />
            </Toolbar.Group>
          </Toolbar>
        }
      >
        <div>
          <Resizable show={selected} onResize={({ width, height }) => onEdit({ width, height })}>
            <img width={props.model.width} height={props.model.height} src={props.model.src} />
          </Resizable>
        </div>
      </HoverContainer>

      <CaptionEditor onEdit={(caption: string) => onEdit({ caption })} model={props.model} />
    </div>
  );
};

interface ModalProps {
  onDone: (x: any) => void;
  onCancel: () => void;
  model: ContentModel.Image;
}
const ImageModal = ({ onDone, onCancel, model }: ModalProps) => {
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
