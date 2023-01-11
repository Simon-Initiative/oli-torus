import React, { useState } from 'react';
import { BaseSelection, Transforms } from 'slate';
import { MIMETYPE_FILTERS } from 'components/media/manager/MediaManager';
import { Command } from 'components/editing/elements/commands/interfaces';
import { Model } from 'data/content/model/elements/factories';
import { modalActions } from 'actions/modal';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { SlateEditor } from 'data/content/model/slate';
import { Maybe } from 'tsmonad';
import { Provider } from 'react-redux';
import { MediaItem } from 'types/media';
import { SELECTION_TYPES } from 'components/media/manager/MediaManager';
import { Modal, ModalSize } from 'components/modal/Modal';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { configureStore } from 'state/store';

const display = (c: any) => window.oliDispatch(modalActions.display(c));
const dismiss = () => window.oliDispatch(modalActions.dismiss());
const store = configureStore();

export function selectImage(
  projectSlug: string,
  selectedUrl?: string,
): Promise<string | undefined> {
  return new Promise((resolve, reject) => {
    const MediaLibrary = () => {
      const [selection, setSelection] = useState(Maybe.nothing<string>());

      const onMediaSelection = (mediaOrUrl: MediaItem[]) =>
        mediaOrUrl && mediaOrUrl.length > 0
          ? setSelection(Maybe.just(mediaOrUrl[0]?.url))
          : setSelection(Maybe.nothing());

      const onUrlChange = (url: string) =>
        url.length > 0 ? setSelection(Maybe.just(url)) : setSelection(Maybe.nothing());

      return (
        <Provider store={store}>
          <Modal
            title="Select Image"
            size={ModalSize.X_LARGE}
            onOk={() => {
              dismiss();
              resolve(selection.valueOrThrow());
            }}
            onCancel={() => {
              dismiss();
              reject();
            }}
            disableOk={selection.caseOf({ just: () => false, nothing: () => true })}
            okLabel="Select"
          >
            <UrlOrUpload
              onUrlChange={onUrlChange}
              onMediaSelectionChange={onMediaSelection}
              projectSlug={projectSlug}
              mimeFilter={MIMETYPE_FILTERS.IMAGE}
              selectionType={SELECTION_TYPES.SINGLE}
              initialSelectionPaths={Maybe.maybe(selectedUrl).caseOf({
                just: (s) => [s],
                nothing: () => undefined,
              })}
            />
          </Modal>
        </Provider>
      );
    };

    display(<MediaLibrary />);
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
    icon: <i className="fa-solid fa-image"></i>,
    description: 'Image',
    execute: execute(onReqMedia),
  });

// Inline images force the media library modal to insert an image
export const insertImageInline = createButtonCommandDesc({
  icon: <i className="fa-solid fa-images"></i>,
  description: 'Image (Inline)',
  execute: (context, editor) =>
    selectImage(context.projectSlug).then((selection) =>
      Maybe.maybe(selection).map((src) =>
        insertAction(editor, editor.selection, 'img_inline', src),
      ),
    ),
});
