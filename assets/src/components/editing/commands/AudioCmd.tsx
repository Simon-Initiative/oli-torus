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
import guid from 'utils/guid';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

export function selectAudio(
  projectSlug: string,
  model: ContentModel.Audio,
): Promise<ContentModel.Audio> {
  return new Promise((resolve, reject) => {
    const selected = { img: null };

    const mediaLibrary = (
      <ModalSelection
        title="Embed audio"
        onInsert={() => {
          dismiss();
          resolve(selected.img as any);
        }}
        onCancel={() => dismiss()}
        disableInsert={true}
      >
        <MediaManager
          projectSlug={projectSlug}
          // eslint-disable-next-line
          onEdit={() => {}}
          mimeFilter={MIMETYPE_FILTERS.AUDIO}
          selectionType={SELECTION_TYPES.SINGLE}
          initialSelectionPaths={[model.src]}
          onSelectionChange={(images: MediaItem[]) => {
            (selected as any).img = ContentModel.audio(images[0].url);
          }}
        />
      </ModalSelection>
    );

    display(mediaLibrary);
  });
}

const libraryCommand: Command = {
  execute: (context, editor: ReactEditor) => {
    const at = editor.selection as any;
    selectAudio(context.projectSlug, ContentModel.audio()).then((img) =>
      Transforms.insertNodes(editor, img, { at }),
    );
  },
  precondition: (editor: ReactEditor) => {
    return true;
  },
};

function createCustomEventCommand(onRequestMedia: (r: any) => Promise<string | boolean>) {
  const customEventCommand: Command = {
    execute: (context, editor: ReactEditor) => {
      const at = editor.selection as any;

      const request = {
        type: 'MediaItemRequest',
        mimeTypes: MIMETYPE_FILTERS.AUDIO,
      };

      onRequestMedia(request).then((r) => {
        if (typeof r === 'string') {
          const img = {
            type: 'img',
            src: r as string,
            id: guid(),
            children: [],
          };
          Transforms.insertNodes(editor, img, { at });
        }
      });
    },
    precondition: (editor: ReactEditor) => {
      return true;
    },
  };
  return customEventCommand;
}

export function getCommand(onRequestMedia: any) {
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
