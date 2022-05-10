import React from 'react';
import { onEditModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Resizable } from 'components/misc/resizable/Resizable';
import { Placeholder } from 'components/editing/elements/common/Placeholder';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { useElementSelected } from 'data/content/utils';
import { selectImage } from 'components/editing/elements/image/imageActions';
import { Maybe } from 'tsmonad';
import { ImageSettings } from 'components/editing/elements/image/imageSettings';

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
        <div className="mb-2">Upload an image from your media library or add one with a URL.</div>
        <div>
          <button
            className="btn btn-primary mr-2"
            onClick={(_e) => {
              selectImage(props.commandContext.projectSlug, props.model.src).then((selection) =>
                Maybe.maybe(selection).map((src) => onEdit({ src })),
              );
            }}
          >
            Choose image
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
          <ImageSettings
            model={props.model}
            onEdit={onEdit}
            commandContext={props.commandContext}
          />
        }
      >
        <div>
          <Resizable show={selected} onResize={({ width, height }) => onEdit({ width, height })}>
            <img width={props.model.width} height={props.model.height} src={props.model.src} />
          </Resizable>
        </div>
      </HoverContainer>
      <CaptionEditor
        onEdit={(caption) => onEdit({ caption })}
        model={props.model}
        commandContext={props.commandContext}
      />
    </div>
  );
};
