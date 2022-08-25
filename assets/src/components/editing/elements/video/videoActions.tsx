import React from 'react';
import { Transforms } from 'slate';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection, { sizes } from 'components/modal/ModalSelection';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { configureStore } from 'state/store';
import { Provider } from 'react-redux';
import { VideoSource } from '../../../../data/content/model/elements/types';

export const insertVideo = createButtonCommandDesc({
  icon: 'smart_display',
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
    let selected: VideoSource | undefined = undefined;

    const onUrlSelection = (url: string) => {
      // The user used the url-input to specify a video url uploaded elsewhere, and we don't have the content type of that.
      // Try to infer it from the filename.
      const knownExtension =
        Object.keys(VIDEO_TYPES).find(
          (extension) => url.substring(url.length - extension.length) === extension,
        ) || DEFAULT_TYPE;

      selected = {
        url,
        contenttype: VIDEO_TYPES[knownExtension],
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
          title="Select Video"
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
            mimeFilter={MIMETYPE_FILTERS.VIDEO}
            selectionType={SELECTION_TYPES.SINGLE}
            initialSelectionPaths={[]}
          />
        </ModalSelection>
      </Provider>
    );

    display(mediaLibrary);
  });
}
