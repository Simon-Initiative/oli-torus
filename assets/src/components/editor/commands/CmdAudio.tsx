import React from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import * as ContentModel from 'data/content/model';
import guid from 'utils/guid';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection from 'components/modal/ModalSelection';
import { MediaManager } from 'components/media/manager/MediaManager.controller';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { Command, CommandDesc } from 'components/editor/commands/interfaces';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

export function selectAudio(projectSlug: string,
  model: ContentModel.Audio): Promise<ContentModel.Audio> {

  return new Promise((resolve, reject) => {

    const selected = { img: null };

    const mediaLibrary =
      <ModalSelection title="Select audio"
        onInsert={() => { dismiss(); resolve(selected.img as any); }}
        onCancel={() => dismiss()}
        disableInsert={true}
      >
        <MediaManager model={model}
          projectSlug={projectSlug}
          onEdit={() => { }}
          mimeFilter={MIMETYPE_FILTERS.AUDIO}
          selectionType={SELECTION_TYPES.SINGLE}
          initialSelectionPaths={[model.src]}
          onSelectionChange={(images: MediaItem[]) => {
            const first : ContentModel.Audio = { type: 'audio', src: images[0].url,
              children: [{ text: '' }], id: guid() };
            (selected as any).img = first;
          }} />
      </ModalSelection>;

    display(mediaLibrary);
  });
}

const command: Command = {
  execute: (context, editor: ReactEditor) => {
    selectAudio(context.projectSlug, ContentModel.audio())
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
  icon: 'audiotrack',
  description: 'Audio Clip',
  command,
};
