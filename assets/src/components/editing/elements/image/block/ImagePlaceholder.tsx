import React from 'react';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { Placeholder } from 'components/editing/elements/common/Placeholder';
import { selectImage } from 'components/editing/elements/image/imageActions';
import { Maybe } from 'tsmonad';

interface Props extends EditorProps<ContentModel.ImageBlock> {}
export function ImagePlaceholder(props: Props) {
  const onEdit = useEditModelCallback(props.model);

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
          onClick={(_e) =>
            selectImage(props.commandContext.projectSlug, props.model.src).then((selection) =>
              Maybe.maybe(selection).map((src) => onEdit({ src })),
            )
          }
        >
          Choose image
        </button>
        {props.children}
      </div>
    </Placeholder>
  );
}
