import React from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import * as ContentModel from 'data/content/model';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection from 'components/modal/ModalSelection';
import { MediaManager } from 'components/media/manager/MediaManager.controller';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { Command, CommandDesc } from 'components/editing/commands/interfaces';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

export function selectAudio(projectSlug: string,
  model: ContentModel.Audio): Promise<ContentModel.Audio> {

  return new Promise((resolve, reject) => {

    const selected = { img: null };

    const mediaLibrary =
      <ModalSelection title="Embed audio"
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
            (selected as any).img = ContentModel.audio(images[0].url);
          }} />
      </ModalSelection>;

    display(mediaLibrary);
  });
}

const command: Command = {
  execute: (context, editor: ReactEditor) => {
    const at = editor.selection as any;
    selectAudio(context.projectSlug, ContentModel.audio())
      .then(img => Transforms.insertNodes(editor, img, { at }));
  },
  precondition: (editor: ReactEditor) => {
    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'audiotrack',
  description: () => 'Audio Clip',
  command,
};
