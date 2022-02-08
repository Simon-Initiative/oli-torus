import React from 'react';
import { Editor, Transforms } from 'slate';
import * as ContentModel from 'data/content/model/nodes/types';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection from 'components/modal/ModalSelection';
import { MediaManager } from 'components/media/manager/MediaManager.controller';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
<<<<<<< HEAD:assets/src/components/editing/nodes/commands/AudioCmd.tsx
import { Command, CommandDesc } from 'components/editing/nodes/commands/interfaces';
import { Model } from 'data/content/model/nodes/factories';
=======
import { Command } from 'components/editing/elements/commands/interfaces';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
>>>>>>> fix-toolbar:assets/src/components/editing/nodes/audio/audioActions.tsx

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

export function selectAudio(
  projectSlug: string,
  model: ContentModel.Audio,
): Promise<ContentModel.Audio> {
  return new Promise((resolve, _reject) => {
    const selected: { audio: null | ContentModel.Audio } = { audio: null };

    const mediaLibrary = (
      <ModalSelection
        title="Embed audio"
        onInsert={() => {
          dismiss();
          if (selected.audio) resolve(selected.audio);
        }}
        onCancel={() => dismiss()}
        disableInsert={true}
      >
        <MediaManager
          projectSlug={projectSlug}
          onEdit={() => {}}
          mimeFilter={MIMETYPE_FILTERS.AUDIO}
          selectionType={SELECTION_TYPES.SINGLE}
          initialSelectionPaths={[model.src || '']}
          onSelectionChange={(audios: MediaItem[]) => {
            selected.audio = Model.audio(audios[0].url);
          }}
        />
      </ModalSelection>
    );

    display(mediaLibrary);
  });
}

function createCustomEventCommand(onRequestMedia: (r: any) => Promise<string | boolean>) {
  const customEventCommand: Command = {
    execute: (_context, editor: Editor) => {
      const at = editor.selection;
      if (!at) return;

      const request = {
        type: 'MediaItemRequest',
        mimeTypes: MIMETYPE_FILTERS.AUDIO,
      };

      onRequestMedia(request).then((r) => {
        if (typeof r === 'string') {
          Transforms.insertNodes(editor, Model.audio(r), { at });
        }
      });
    },
    precondition: (_editor: Editor) => {
      return true;
    },
  };
  return customEventCommand;
}

export const insertAudio = (onRequestMedia: any) =>
  createButtonCommandDesc({
    icon: 'audiotrack',
    description: 'Audio Clip',
    ...(onRequestMedia === null || onRequestMedia === undefined
      ? {
          execute: (context, editor: Editor) => {
            const at = editor.selection as any;
            selectAudio(context.projectSlug, Model.audio()).then((audio) =>
              Transforms.insertNodes(editor, audio, { at }),
            );
          },
        }
      : createCustomEventCommand(onRequestMedia)),
  });
