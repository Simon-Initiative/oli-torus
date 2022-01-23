import React from 'react';
import { Editor, Transforms } from 'slate';
import * as ContentModel from 'data/content/model/elements/types';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection from 'components/modal/ModalSelection';
import { MediaManager } from 'components/media/manager/MediaManager.controller';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { Command, CommandDesc } from 'components/editing/elements/commands/interfaces';
import { audio } from 'data/content/model/elements/factories';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

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
          initialSelectionPaths={[model.src]}
          onSelectionChange={(audios: MediaItem[]) => {
            selected.audio = audio(audios[0].url);
          }}
        />
      </ModalSelection>
    );

    display(mediaLibrary);
  });
}

const libraryCommand: Command = {
  execute: (context, editor: Editor) => {
    const at = editor.selection as any;
    selectAudio(context.projectSlug, audio()).then((audio) =>
      Transforms.insertNodes(editor, audio, { at }),
    );
  },
  precondition: (_editor: Editor) => {
    return true;
  },
};

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
          Transforms.insertNodes(editor, audio(r), { at });
        }
      });
    },
    precondition: (_editor: Editor) => {
      return true;
    },
  };
  return customEventCommand;
}

export function audioCmdDescBuilder(onRequestMedia: any) {
  const commandDesc: CommandDesc = {
    type: 'CommandDesc',
    icon: () => 'audiotrack',
    description: () => 'Audio Clip',
    command:
      onRequestMedia === null || onRequestMedia === undefined
        ? libraryCommand
        : createCustomEventCommand(onRequestMedia),
  };
  return commandDesc;
}
