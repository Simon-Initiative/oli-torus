import React from 'react';
import { ReactEditor, useFocused, useSelected } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel } from './utils';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection from 'components/modal/ModalSelection';
import { MediaManager } from 'components/media/manager/MediaManager.controller';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

export function selectImage(projectSlug: string,
  model: ContentModel.Image): Promise<ContentModel.Image> {

  return new Promise((resolve, reject) => {

    const selected = { img: null };

    const mediaLibrary =
        <ModalSelection title="Select an image"
          onInsert={() => { dismiss(); resolve(selected.img as any); }}
          onCancel={() => dismiss()}
          disableInsert={true}
        >
          <MediaManager model={model}
            projectSlug={projectSlug}
            onEdit={() => { }}
            mimeFilter={MIMETYPE_FILTERS.IMAGE}
            selectionType={SELECTION_TYPES.SINGLE}
            initialSelectionPaths={model.src ? [model.src] : [selected.img as any]}
            onSelectionChange={(images: MediaItem[]) => {
              const first : ContentModel.Image = { type: 'img', src: images[0].url,
                children: [{ text: '' }], id: guid()};
              (selected as any).img = first;
            }} />
        </ModalSelection>;

    display(mediaLibrary);
  });
}

const command: Command = {
  execute: (context, editor: ReactEditor) => {
    const image = ContentModel.create<ContentModel.Image>(
      { type: 'img', src: '', children: [{ text: '' }], id: guid() });
    selectImage(context.projectSlug, image)
    .then((img) => {
      Transforms.insertNodes(editor, img);
    });
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'image',
  description: 'Image',
  command,
};

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
  ? { border: 'solid 2px lightblue' } : {};

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
              className="img-fluid img-thumbnail"
              src={model.src}
              draggable={false}
            />
            <figcaption>
              <input
                type="text"
                value={model.caption}
                placeholder="Type caption for image"
                onChange={e => {
                  setCaptionAndAlt(e.target.value)
                }}
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
