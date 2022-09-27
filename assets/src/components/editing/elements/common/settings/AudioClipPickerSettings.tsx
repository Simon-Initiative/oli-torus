import React from 'react';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection, { sizes } from 'components/modal/ModalSelection';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { configureStore } from 'state/store';
import { Provider } from 'react-redux';
import { AudioSource } from '../../../../../data/content/model/elements/types';

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
        <ModalSelection
          title="Select Audio"
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
            mimeFilter={MIMETYPE_FILTERS.AUDIO}
            selectionType={SELECTION_TYPES.SINGLE}
            initialSelectionPaths={[]}
          />
        </ModalSelection>
      </Provider>
    );

    display(mediaLibrary);
  });
}
