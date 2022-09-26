import React, { useState } from 'react';
import { Transforms } from 'slate';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import { Modal, ModalSize } from 'components/modal/Modal';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { configureStore } from 'state/store';
import { Provider } from 'react-redux';
import { AudioSource } from '../../../../data/content/model/elements/types';
import { insideSemanticElement } from '../utils';
import { Maybe } from 'tsmonad';

export const insertDefinition = createButtonCommandDesc({
  icon: 'menu_book',
  description: 'Definition',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;
    Transforms.insertNodes(editor, Model.definition(), { at });
  },
  precondition: (editor) => !insideSemanticElement(editor),
});

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));
const store = configureStore();

export function selectAudio(
  projectSlug: string,
  _selectedUrl?: string,
): Promise<AudioSource | undefined> {
  return new Promise((resolve, _reject) => {
    const MediaLibrary = () => {
      const [selection, setSelection] = useState(Maybe.nothing<AudioSource>());

      const onUrlSelection = (url: string) => {
        if (url.length > 0) {
          setSelection(
            Maybe.just({
              url,
              contenttype: 'audio/mp3',
            }),
          );
        } else {
          setSelection(Maybe.nothing());
        }
      };

      const onMediaSelection = (mediaOrUrl: MediaItem[]) => {
        if (mediaOrUrl && mediaOrUrl.length > 0) {
          // The user picked a MediaItem from the media library which has mime info with it.
          setSelection(
            Maybe.just({
              url: mediaOrUrl[0].url,
              contenttype: mediaOrUrl[0].mimeType,
            }),
          );
        } else {
          setSelection(Maybe.nothing());
        }
      };

      return (
        <Provider store={store}>
          <Modal
            title="Select Audio"
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
              mimeFilter={MIMETYPE_FILTERS.AUDIO}
              selectionType={SELECTION_TYPES.SINGLE}
              initialSelectionPaths={[]}
            />
          </Modal>
        </Provider>
      );
    };

    display(<MediaLibrary />);
  });
}
