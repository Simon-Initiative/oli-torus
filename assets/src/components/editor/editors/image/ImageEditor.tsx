import React from 'react';
import { ReactEditor, useFocused, useSelected } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel } from 'components/editor/editors/utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editor/editors/interfaces';

export interface ImageProps extends EditorProps<ContentModel.Image> {
}

export interface ImageState {
}

export const ImageEditor = (props: ImageProps) => {

  const { attributes, children, editor } = props;
  const { model } = props;

  const focused = useFocused();
  const selected = useSelected();

  const onEdit = (updated: ContentModel.Image) => {
    updateModel<ContentModel.Image>(editor, props.model, updated);
  };

  const setCaptionAndAlt = (text: string) =>
    onEdit(Object.assign({}, model, { caption: text, alt: text }));

  const imageStyle = focused && selected
  ? { border: 'solid 3px lightblue', borderRadius: 0 } : { border: 'solid 3px transparent' };

  // Note that it is important that any interactive portions of a void editor
  // must be enclosed inside of a "contentEditable=false" container. Otherwise,
  // slate does some weird things that non-deterministically interface with click
  // events.

  return (
    <div {...attributes} className="ml-4 mr-4">

      <div contentEditable={false} style={{ userSelect: 'none' }}>
        <div className="ml-4 mr-4 text-center">
          <figure>
            <img
              style={imageStyle}
              className="img-fluid"
              src={model.src}
              draggable={false}
              onClick={e => Transforms.select(editor, ReactEditor.findPath(editor, model))}
            />
            <figcaption>
              <input
                type="text"
                value={model.caption}
                placeholder="Type caption for image"
                onChange={e => setCaptionAndAlt(e.target.value)}
                // onKeyPress={e => e.key === 'Enter' ?  : null}
                // onKeyPress={e => Settings.onEnterApply(e, () => onEdit(model))}
                className="caption-editor"
              />
            </figcaption>
          </figure>
        </div>
      </div>

      {children}
    </div>
  );
};
