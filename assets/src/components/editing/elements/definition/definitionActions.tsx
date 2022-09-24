import React from 'react';
import { Transforms } from 'slate';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import Modal, { ModalSize } from 'components/modal/Modal';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { configureStore } from 'state/store';
import { Provider } from 'react-redux';
import { AudioSource } from '../../../../data/content/model/elements/types';
import { insideSemanticElement } from '../utils';

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
    let selected: AudioSource | undefined = undefined;

    const onUrlSelection = (url: string) => {
      selected = {
        url,
        contenttype: 'audio/mp3',
      };
    };

    const onMediaSelection = (mediaOrUrl: MediaItem[]) => {
      if (!mediaOrUrl || mediaOrUrl.length === 0) {
        selected = undefined;
      } else {
        // The user picked a MediaItem from the media library which has mime info with it.
        selected = {
          url: mediaOrUrl[0].url,
          contenttype: mediaOrUrl[0].mimeType,
        };
      }
    };

    const mediaLibrary = (
      <Provider store={store}>
        <Modal
          title="Select Audio"
          size={ModalSize.X_LARGE}
          onInsert={() => {
            dismiss();
            resolve(selected);
          }}
          onCancel={dismiss}
          disableInsert={true}
          okLabel="Select"
        >
          <UrlOrUpload
            onUrlChange={onUrlSelection}
            onMediaSelectionChange={onMediaSelection}
            projectSlug={projectSlug}
            onEdit={() => {}}
            mimeFilter={MIMETYPE_FILTERS.AUDIO}
            selectionType={SELECTION_TYPES.SINGLE}
            initialSelectionPaths={[]}
          />
        </Modal>
      </Provider>
    );

    display(mediaLibrary);
  });
}
