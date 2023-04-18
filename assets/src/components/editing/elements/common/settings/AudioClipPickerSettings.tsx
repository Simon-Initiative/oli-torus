import React, { useState } from 'react';
import { Provider } from 'react-redux';
import { Maybe } from 'tsmonad';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import { Modal, ModalSize } from 'components/modal/Modal';
import { modalActions } from 'actions/modal';
import { configureStore } from 'state/store';
import { MediaItem } from 'types/media';
import { AudioSource } from '../../../../../data/content/model/elements/types';

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));
const store = configureStore();

interface Props {
  resolve: (src: AudioSource) => void;
  projectSlug: string;
}

export const AudioClipProvider: React.FC = ({ children }) => {
  return <Provider store={store}>{children}</Provider>;
};

const MediaLibrary: React.FC<Props> = ({ projectSlug, resolve }) => {
  const [selected, setSelected] = useState(Maybe.nothing<AudioSource>());

  const onUrlSelection = (url: string) => {
    if (url.length > 0) {
      setSelected(
        Maybe.just({
          url,
          contenttype: 'audio/mp3',
        }),
      );
    } else {
      setSelected(Maybe.nothing());
    }
  };

  const onMediaSelection = (mediaOrUrl: MediaItem[]) => {
    if (mediaOrUrl && mediaOrUrl.length > 0) {
      // The user picked a MediaItem from the media library which has mime info with it.
      setSelected(
        Maybe.just({
          url: mediaOrUrl[0].url,
          contenttype: mediaOrUrl[0].mimeType,
        }),
      );
    } else {
      setSelected(Maybe.nothing());
    }
  };
  return (
    <AudioClipProvider>
      <Modal
        backdrop="static"
        title="Select Audio"
        size={ModalSize.X_LARGE}
        onOk={() => {
          dismiss();
          resolve(selected.valueOrThrow());
        }}
        onCancel={dismiss}
        disableOk={selected.caseOf({ just: () => false, nothing: () => true })}
        okLabel="Select"
      >
        <UrlOrUpload
          onUrlChange={onUrlSelection}
          onMediaSelectionChange={onMediaSelection}
          projectSlug={projectSlug}
          mimeFilter={MIMETYPE_FILTERS.AUDIO}
          selectionType={SELECTION_TYPES.SINGLE}
        />
      </Modal>
    </AudioClipProvider>
  );
};

export function selectAudio(
  projectSlug: string,
  _selectedUrl?: string,
): Promise<AudioSource | undefined> {
  return new Promise((resolve, _reject) => {
    display(<MediaLibrary projectSlug={projectSlug} resolve={resolve} />);
  });
}
