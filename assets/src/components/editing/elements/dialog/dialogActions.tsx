import React from 'react';

import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection, { sizes } from 'components/modal/ModalSelection';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { configureStore } from 'state/store';
import { Provider } from 'react-redux';
import { createButtonCommandDesc } from '../commands/commandFactories';
import { Transforms } from 'slate';
import { Model } from '../../../../data/content/model/elements/factories';

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));
const store = configureStore();

export const insertDialog = createButtonCommandDesc({
  icon: 'record_voice_over',
  description: 'Dialog',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.dialog('Dialog'), { at });
  },
});

export function selectPortrait(projectSlug: string): Promise<string | undefined> {
  return new Promise((resolve, _reject) => {
    let selected: string | undefined = undefined;

    const onUrlSelection = (url: string) => {
      selected = url;
    };

    const onMediaSelection = (mediaOrUrl: MediaItem[]) => {
      if (!mediaOrUrl || mediaOrUrl.length === 0) {
        selected = undefined;
      } else {
        // The user picked a MediaItem from the media library which has mime info with it.
        selected = mediaOrUrl[0].url;
      }
    };

    const mediaLibrary = (
      <Provider store={store}>
        <ModalSelection
          title="Select Image"
          size={sizes.extraLarge}
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
            mimeFilter={MIMETYPE_FILTERS.IMAGE}
            selectionType={SELECTION_TYPES.SINGLE}
            initialSelectionPaths={[]}
          />
        </ModalSelection>
      </Provider>
    );

    display(mediaLibrary);
  });
}
