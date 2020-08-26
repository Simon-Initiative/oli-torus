import React from 'react';
import { Transforms } from 'slate';
import * as ContentModel from 'data/content/model';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection from 'components/modal/ModalSelection';
import { MediaManager } from 'components/media/manager/MediaManager.controller';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { Command, CommandDesc } from 'components/editor/commands/interfaces';

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
              (selected as any).img = ContentModel.image(images[0].url);
            }} />
        </ModalSelection>;

    display(mediaLibrary);
  });
}

const command: Command = {
  execute: (context, editor) => {
    selectImage(context.projectSlug, ContentModel.image())
    .then(img =>  Transforms.insertNodes(editor, img));
  },
  precondition: (editor) => {
    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'image',
  description: () => 'Image',
  command,
};
