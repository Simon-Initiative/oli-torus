import React, { useState } from 'react';
import { Editor, Transforms } from 'slate';
import * as ContentModel from 'data/content/model/elements/types';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import { Modal } from 'components/modal/Modal';
import { MediaManager } from 'components/media/manager/MediaManager.controller';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { configureStore } from 'state/store';
import { Provider } from 'react-redux';
import { Maybe } from 'tsmonad';

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));
const store = configureStore();

export function selectAudio(
  projectSlug: string,
  model: ContentModel.Audio,
): Promise<ContentModel.Audio> {
  return new Promise((resolve, _reject) => {
    const MediaLibrary = () => {
      const [selection, setSelection] = useState(Maybe.nothing<ContentModel.Audio>());

      return (
        <Provider store={store}>
          <Modal
            title="Embed audio"
            onOk={() => {
              dismiss();
              resolve(selection.valueOrThrow());
            }}
            onCancel={() => dismiss()}
            disableOk={selection.caseOf({ just: () => false, nothing: () => true })}
          >
            <MediaManager
              projectSlug={projectSlug}
              mimeFilter={MIMETYPE_FILTERS.AUDIO}
              selectionType={SELECTION_TYPES.SINGLE}
              initialSelectionPaths={[model.src || '']}
              onSelectionChange={(audios: MediaItem[]) =>
                setSelection(Maybe.just(Model.audio(audios[0].url)))
              }
            />
          </Modal>
        </Provider>
      );
    };

    display(<MediaLibrary />);
  });
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export const insertAudio = (onRequestMedia: any) =>
  createButtonCommandDesc({
    icon: <i className="fa-solid fa-music"></i>,
    description: 'Audio Clip',

    execute: (context, editor: Editor) => {
      const at = editor.selection as any;
      selectAudio(context.projectSlug, Model.audio()).then((audio) =>
        Transforms.insertNodes(editor, audio, { at }),
      );
    },
  });
