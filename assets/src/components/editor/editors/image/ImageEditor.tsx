import React, { useRef } from 'react';
import { useFocused, useSelected, ReactEditor } from 'slate-react';
import { updateModel } from 'components/editor/editors/utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editor/editors/interfaces';
import * as Settings from '../settings/Settings';
import { Transforms, Editor } from 'slate';

export interface ImageProps extends EditorProps<ContentModel.Image> {
}

export const ImageEditor = (props: ImageProps) => {

  const { attributes, children, editor, model } = props;

  const focused = useFocused();
  const selected = useSelected();

  const ref = useRef();

  const onEdit = (updated: ContentModel.Image) => {
    updateModel<ContentModel.Image>(editor, props.model, updated);
  };

  const setCaptionAndAlt = (text: string) => {
    onEdit(Object.assign({}, model, { caption: text, alt: text }));
  };

  const imageStyle = focused && selected
    ? { border: 'solid 3px lightblue', borderRadius: 0 } : { border: 'solid 3px transparent' };

  // Note that it is important that any interactive portions of a void editor
  // must be enclosed inside of a "contentEditable=false" container. Otherwise,
  // slate does some weird things that non-deterministically interface with click
  // events.

  return (
    <div {...attributes} className="ml-4 mr-4">

      <div contentEditable={false} style={{ userSelect: 'none' }}>
        <div
          className="ml-4 mr-4 text-center">
          <figure>
            <img
              onClick={(e) => {
                console.log('before', focused, selected)
                console.log('focused?', ReactEditor.isFocused(editor));
                ReactEditor.focus(editor);
                Transforms.select(editor, ReactEditor.findPath(editor, model));
                console.log('after focus and select', focused, selected);
              }}
              ref={ref as any}
              style={imageStyle}
              className="img-fluid"
              src={model.src}
              draggable={false}
            />
            <figcaption contentEditable={false} style={{ userSelect: 'none' }}>
              <Settings.Input
                value={model.caption}
                onChange={value => setCaptionAndAlt(value)}
                editor={editor}
                model={model}
                placeholder="Type caption for image"
              />
            </figcaption>
          </figure>
        </div>
      </div>

      {children}
    </div>
  );
};
