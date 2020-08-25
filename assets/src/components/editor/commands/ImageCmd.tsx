import React from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms, Editor } from 'slate';
import * as ContentModel from 'data/content/model';
import guid from 'utils/guid';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection from 'components/modal/ModalSelection';
import { MediaManager } from 'components/media/manager/MediaManager.controller';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { Command, CommandDesc } from 'components/editor/commands/interfaces';
import { isActiveList } from '../utils';

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
    selectImage(context.projectSlug, ContentModel.image())
    .then((img) => {
      Editor.withoutNormalizing(editor, () => {

        Transforms.insertNodes(editor, img);

        if (isActiveList(editor)) {
          Transforms.wrapNodes(editor,
            { type: 'li', children: [] },
            { match: n => n.type === 'img' });
        }
      });
    });
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'image',
  description: () => 'Image',
  command,
};
