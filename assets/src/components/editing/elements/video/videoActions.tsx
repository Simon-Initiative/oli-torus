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
import { VideoSource } from '../../../../data/content/model/elements/types';
import { Maybe } from 'tsmonad';

export const insertVideo = createButtonCommandDesc({
  icon: <i className="fa-solid fa-circle-play"></i>,
  description: 'Video',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.video(), { at });
  },
});

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));
const store = configureStore();

const VIDEO_TYPES: Record<string, string> = {
  mpgeg: 'video/mpeg',
  mpg: 'video/mpeg',
  mp4: 'video/mp4',
  webm: 'video/webm',
  ogg: 'video/ogg',
  qt: 'video/quicktime',
  mov: 'video/quicktime',
};

const DEFAULT_TYPE = 'mp4';

export function selectVideo(
  projectSlug: string,
  _selectedUrl?: string,
): Promise<VideoSource | undefined> {
  return new Promise((resolve, _reject) => {
    const MediaLibrary = () => {
      const [selection, setSelection] = useState(Maybe.nothing<VideoSource>());

      const onUrlSelection = (url: string) => {
        if (url.length > 0) {
          // The user used the url-input to specify a video url uploaded elsewhere, and we don't have the content type of that.
          // Try to infer it from the filename.
          const knownExtension =
            Object.keys(VIDEO_TYPES).find(
              (extension) => url.substring(url.length - extension.length) === extension,
            ) || DEFAULT_TYPE;

          setSelection(
            Maybe.just({
              url,
              contenttype: VIDEO_TYPES[knownExtension],
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
            title="Select Video"
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
              mimeFilter={MIMETYPE_FILTERS.VIDEO}
              selectionType={SELECTION_TYPES.SINGLE}
            />
          </Modal>
        </Provider>
      );
    };

    display(<MediaLibrary />);
  });
}
