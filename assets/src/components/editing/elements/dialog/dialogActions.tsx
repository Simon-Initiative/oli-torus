import React, { useState } from 'react';

import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import { Modal, ModalSize } from 'components/modal/Modal';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { configureStore } from 'state/store';
import { Provider } from 'react-redux';
import { createButtonCommandDesc } from '../commands/commandFactories';
import { Transforms } from 'slate';
import { Model } from '../../../../data/content/model/elements/factories';
import { Maybe } from 'tsmonad';

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));
const store = configureStore();

export const insertDialog = createButtonCommandDesc({
  icon: <i className="fa-regular fa-comment-dots"></i>,
  description: 'Dialog',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.dialog('Dialog'), { at });
  },
});

export function selectPortrait(projectSlug: string): Promise<string | undefined> {
  return new Promise((resolve, _reject) => {
    const MediaLibrary = () => {
      const [selection, setSelection] = useState(Maybe.nothing<string>());

      const onUrlSelection = (url: string) => {
        if (url.length > 0) {
          setSelection(Maybe.just(url));
        } else {
          setSelection(Maybe.nothing());
        }
      };

      const onMediaSelection = (mediaOrUrl: MediaItem[]) => {
        if (mediaOrUrl && mediaOrUrl.length > 0) {
          // The user picked a MediaItem from the media library which has mime info with it.
          setSelection(Maybe.just(mediaOrUrl[0].url));
        } else {
          setSelection(Maybe.nothing());
        }
      };

      return (
        <Provider store={store}>
          <Modal
            title="Select Image"
            size={ModalSize.X_LARGE}
            onOk={() => {
              dismiss();
              resolve(selection.valueOrThrow());
            }}
            onCancel={dismiss}
            disableOk={selection.caseOf({ just: () => false, nothing: () => true })}
            okLabel="Select"
          >
            <UrlOrUpload
              onUrlChange={onUrlSelection}
              onMediaSelectionChange={onMediaSelection}
              projectSlug={projectSlug}
              mimeFilter={MIMETYPE_FILTERS.IMAGE}
              selectionType={SELECTION_TYPES.SINGLE}
            />
          </Modal>
        </Provider>
      );
    };

    display(<MediaLibrary />);
  });
}
