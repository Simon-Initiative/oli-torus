import React from 'react';
import { BaseSelection, Transforms } from 'slate';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import Modal, { ModalSize } from 'components/modal/Modal';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { Command } from 'components/editing/elements/commands/interfaces';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { configureStore } from 'state/store';
import { Provider } from 'react-redux';
import { SlateEditor } from 'data/content/model/slate';
import { Maybe } from 'tsmonad';

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
        <Modal
          title="Select Image"
          size={ModalSize.X_LARGE}
          onInsert={() => {
            dismiss();
            resolve(selectedUrl);
          }}
          onCancel={dismiss}
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
        </Modal>
      </Provider>
    );

    display(mediaLibrary);
  });
}

const insertAction = (
  editor: SlateEditor,
  at: BaseSelection,
  type: 'img' | 'img_inline',
  src: undefined | string = undefined,
) =>
  Transforms.insertNodes(
    editor,
    type === 'img' ? Model.image(src) : Model.imageInline(src),
    at ? { at } : undefined,
  );

// Block images insert the placeholder block by default
const execute =
  (onReqMedia: any): Command['execute'] =>
  (_context, editor) =>
    onReqMedia === null || onReqMedia === undefined
      ? insertAction(editor, editor.selection, 'img')
      : onReqMedia({
          type: 'MediaItemRequest',
          mimeTypes: MIMETYPE_FILTERS.IMAGE,
        }).then(
          (src: any) =>
            typeof src === 'string' && insertAction(editor, editor.selection, 'img', src),
        );

export const insertImage = (onReqMedia: any) =>
  createButtonCommandDesc({
    icon: 'image',
    description: 'Image',
    execute: execute(onReqMedia),
  });

// Inline images force the media library modal to insert an image
export const insertImageInline = createButtonCommandDesc({
  icon: 'burst_mode',
  description: 'Image (Inline)',
  execute: (context, editor) =>
    selectImage(context.projectSlug).then((selection) =>
      Maybe.maybe(selection).map((src) =>
        insertAction(editor, editor.selection, 'img_inline', src),
      ),
    ),
});
