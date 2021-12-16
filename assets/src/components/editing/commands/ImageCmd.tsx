import React from 'react';
import { Editor, Transforms } from 'slate';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection, { sizes } from 'components/modal/ModalSelection';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { image } from 'data/content/model/elements/factories';
import { ButtonCommand } from 'components/editing/toolbar/interfaces';
import { toolbarButtonDesc } from 'components/editing/toolbar/commands';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

export function selectImage(
  projectSlug: string,
  _selectedUrl?: string,
): Promise<string | undefined> {
  return new Promise((resolve, _reject) => {
    let selectedUrl: string | undefined = undefined;

    const mediaLibrary = (
      <ModalSelection
        title="Select Image"
        size={sizes.extraLarge}
        onInsert={() => {
          dismiss();
          resolve(selectedUrl);
        }}
        onCancel={() => dismiss()}
        disableInsert={true}
        okLabel="Select"
      >
        <UrlOrUpload
          onUrlChange={(url: string) => (selectedUrl = url)}
          onMediaSelectionChange={(mediaOrUrl: MediaItem[]) => (selectedUrl = mediaOrUrl[0]?.url)}
          projectSlug={projectSlug}
          onEdit={() => {}}
          mimeFilter={MIMETYPE_FILTERS.IMAGE}
          selectionType={SELECTION_TYPES.SINGLE}
          initialSelectionPaths={selectedUrl ? [selectedUrl] : []}
        />
      </ModalSelection>
    );

    display(mediaLibrary);
  });
}

const libraryCommand: ButtonCommand = {
  execute: (context, editor) => {
    const at = editor.selection;
    selectImage(context.projectSlug, undefined).then((src) =>
      Transforms.insertNodes(editor, image(src), at ? { at } : undefined),
    );
  },
  precondition: (_editor) => {
    return true;
  },
};

function createCustomEventCommand(onRequestMedia: (r: any) => Promise<string | boolean>) {
  const customEventCommand: ButtonCommand = {
    execute: (_context, editor: Editor) => {
      const at = editor.selection;

      const request = {
        type: 'MediaItemRequest',
        mimeTypes: MIMETYPE_FILTERS.IMAGE,
      };

      onRequestMedia(request).then((r) => {
        if (typeof r === 'string') {
          Transforms.insertNodes(editor, image(r), at ? { at } : undefined);
        }
      });
    },
    precondition: (_editor) => {
      return true;
    },
  };
  return customEventCommand;
}

export function getCommand(onRequestMedia: any) {
  return toolbarButtonDesc({
    icon: () => 'image',
    description: () => 'Image',
    ...(onRequestMedia === null || onRequestMedia === undefined
      ? libraryCommand
      : createCustomEventCommand(onRequestMedia)),
  });
}
