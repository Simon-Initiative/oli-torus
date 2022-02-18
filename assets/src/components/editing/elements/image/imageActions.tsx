import React from 'react';
import { Editor, Transforms } from 'slate';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection, { sizes } from 'components/modal/ModalSelection';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { Command } from 'components/editing/elements/commands/interfaces';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { configureStore } from 'state/store';
import { Provider } from 'react-redux';

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));
const store = configureStore();

export function selectImage(
  projectSlug: string,
  _selectedUrl?: string,
): Promise<string | undefined> {
  return new Promise((resolve, _reject) => {
    let selectedUrl: string | undefined = undefined;

    const mediaLibrary = (
      <Provider store={store}>
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
      </Provider>
    );

    display(mediaLibrary);
  });
}

function createCustomEventCommand(onRequestMedia: (r: any) => Promise<string | boolean>) {
  const customEventCommand: Command = {
    execute: (context, editor: Editor) => {
      const at = editor.selection;

      const request = {
        type: 'MediaItemRequest',
        mimeTypes: MIMETYPE_FILTERS.IMAGE,
      };

      onRequestMedia(request).then((r) => {
        if (typeof r === 'string') {
          Transforms.insertNodes(editor, Model.image(r), at ? { at } : undefined);
        }
      });
    },
    precondition: (_editor) => {
      return true;
    },
  };
  return customEventCommand;
}

export const insertImage = (onRequestMedia: any) =>
  createButtonCommandDesc({
    icon: 'image',
    description: 'Image',
    ...(onRequestMedia === null || onRequestMedia === undefined
      ? {
          execute: (context, editor) => {
            const at = editor.selection;
            Transforms.insertNodes(editor, Model.image(), at ? { at } : undefined);
          },
          precondition: (_editor) => {
            return true;
          },
        }
      : createCustomEventCommand(onRequestMedia)),
  });
